import atfoundation

private enum ModuleMapType: String {
    case Synthesized = "synthesized"
}

private enum Options: String {
    case InfoPlist = "info-plist"
    case Name = "name"
}

func env(_ feature: String) -> String? {
    let env = getenv(feature)
    guard let e = env else { return nil }
    return String(validatingUTF8: e)
}

func arg(_ larg: String) -> String? {
    for (x, arg) in Process.arguments.enumerated() {
        if arg == "--\(larg)" { return Process.arguments[x+1] }
    }
    return nil
}

class PackageFramework {
    func run() {

        guard let platform = env("ATBUILD_PLATFORM") else {
            fatalError("Set $ATBUILD_PLATFORM")
        }
        let architecture: String
        switch (platform) {
            case "osx":
            architecture = "x86_64"
            default:
            fatalError("Unsupported platform \(platform)")
        }

        guard let name = arg(Options.Name.rawValue) else {
            fatalError("Specify a \(Options.Name.rawValue)")
        }

        guard let infoPlist = arg(Options.InfoPlist.rawValue) else {
            fatalError("Specify a \(Options.InfoPlist.rawValue)")
        }
        var resources: [String] = [infoPlist]

        //rm framework if it exists
        let frameworkPath = Path("bin/\(name).framework")
        let _ = try? FS.removeItem(path: frameworkPath, recursive: true)
        let _ = try? FS.createDirectory(path: frameworkPath)

        //'a' version
        let relativeAVersionPath = Path("Versions/A")
        let AVersionPath = frameworkPath + relativeAVersionPath
        try! FS.createDirectory(path: AVersionPath, intermediate: true)
        //'current' (produces code signing failures if absent)
        try! FS.symlinkItem(from: Path("A"), to: frameworkPath + "Versions/Current")
        //copy payload
        //atbin path
        let atbinPath = Path("bin").appending("\(name).atbin")
        let payloadPath = atbinPath.appending(name + ".dylib")
        try! FS.copyItem(from: payloadPath, to: AVersionPath.appending(name))
        try! FS.symlinkItem(from: relativeAVersionPath.appending(name), to: frameworkPath.appending(name))

        //copy modules
        let modulePath = AVersionPath.appending("Modules").appending(name + ".swiftmodule")
        try! FS.createDirectory(path: modulePath, intermediate: true)

        let swiftModulePath = atbinPath.appending("\(platform).swiftmodule")
        if FS.fileExists(path: swiftModulePath) {
            try! FS.copyItem(from: swiftModulePath, to: modulePath.appending("\(architecture).swiftmodule"))
        }
        let swiftDocPath = atbinPath.appending("\(platform).swiftdoc")
        if FS.fileExists(path: swiftDocPath) {
            try! FS.copyItem(from: swiftDocPath, to: modulePath.appending("\(architecture).swiftdoc"))
        }
        try! FS.symlinkItem(from: relativeAVersionPath.appending("Modules"), to: frameworkPath.appending("Modules"))

        //copy resources
        let resourcesPath = AVersionPath.appending("Resources")
        try! FS.createDirectory(path: resourcesPath, intermediate: true)
        for resource in resources {
            try! FS.copyItem(from: Path(resource), to: resourcesPath + resource)
        }
        try! FS.symlinkItem(from: relativeAVersionPath + "Resources", to: frameworkPath + "Resources")

        //codesign
        let cmd = "codesign --force --deep --sign - --timestamp=none '\(AVersionPath)'"
        print(cmd)
        if system(cmd) != 0 {
            fatalError("Codesign failed.")
        }
    }
}

PackageFramework().run()