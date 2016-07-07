// Copyright (c) 2016 Anarchy Tools Contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import atfoundation

private enum ModuleMapType: String {
    case Synthesized = "synthesized"
}

private enum Options: String {
    case InfoPlist = "info-plist"
    case Name = "name"
    case Compress = "compress"
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

        guard let atbuildPlatform = env("ATBUILD_PLATFORM") else {
            fatalError("Set $ATBUILD_PLATFORM")
        }
        let platformToArch: [String:String]
        switch (atbuildPlatform) {
            case "osx":
            platformToArch = ["osx":"x86_64"]
            case "ios":
            platformToArch = ["ios-arm64":"arm64","ios-armv7":"armv7","ios-i386":"i386","ios-x86_64":"x86_64"]
            default:
            fatalError("Unsupported platform \(atbuildPlatform)")
        }

        guard let name = arg(Options.Name.rawValue) else {
            fatalError("Specify a \(Options.Name.rawValue)")
        }

        guard let infoPlist = arg(Options.InfoPlist.rawValue) else {
            fatalError("Specify a \(Options.InfoPlist.rawValue)")
        }

        let compress: Bool

        if let c = arg(Options.Compress.rawValue) {
            if c == "true" { compress = true } else { compress = false}
        } else { compress = false }

        var resources: [String] = [infoPlist]

        //rm framework if it exists
        let frameworkPath = Path("bin/\(name).framework")
        let _ = try? FS.removeItem(path: frameworkPath, recursive: true)
        let _ = try? FS.createDirectory(path: frameworkPath)

        //'a' version
        let relativeAVersionPath: Path!
        let AVersionPath: Path
        switch(atbuildPlatform) {
            case "osx":
            relativeAVersionPath = Path("Versions/A")
            AVersionPath = frameworkPath + relativeAVersionPath
            case "ios":
            relativeAVersionPath = nil
            AVersionPath = frameworkPath
            default:
            fatalError("Unsupported platform \(atbuildPlatform)")
        }

        if atbuildPlatform == "osx" {
            try! FS.createDirectory(path: AVersionPath, intermediate: true)
            //'current' (produces code signing failures if absent)
            try! FS.symlinkItem(from: Path("A"), to: frameworkPath + "Versions/Current")
        }

        //copy payload
        //atbin path
        let atbinPath = Path(env("ATBUILD_BIN_PATH")!).appending("\(name).atbin")
        let payloadPath = atbinPath.appending(name + ".dylib")
        try! FS.copyItem(from: payloadPath, to: AVersionPath.appending(name))
        if atbuildPlatform == "osx" {
            try! FS.symlinkItem(from: relativeAVersionPath.appending(name), to: frameworkPath.appending(name))
        }
        //copy modules
        let modulePath = AVersionPath.appending("Modules").appending(name + ".swiftmodule")
        try! FS.createDirectory(path: modulePath, intermediate: true)
        for (platform, architecture) in platformToArch {
            //In frameworks, what AT calls "armv7" is called "arm".
            let destArchitecture: String 
            if architecture == "armv7" { destArchitecture = "arm" }
            else { destArchitecture = architecture }

            let swiftModulePath = atbinPath.appending("\(platform).swiftmodule")
            if FS.fileExists(path: swiftModulePath) {
                try! FS.copyItem(from: swiftModulePath, to: modulePath.appending("\(destArchitecture).swiftmodule"))
            }

            let swiftDocPath = atbinPath.appending("\(platform).swiftdoc")
            if FS.fileExists(path: swiftDocPath) {
                try! FS.copyItem(from: swiftDocPath, to: modulePath.appending("\(destArchitecture).swiftdoc"))
            }
        }
        if atbuildPlatform == "osx" {
            try! FS.symlinkItem(from: relativeAVersionPath.appending("Modules"), to: frameworkPath.appending("Modules"))
        }

        //copy resources
        let resourcesPath: Path
        switch(atbuildPlatform) {
            case "osx":
            resourcesPath = AVersionPath.appending("Resources")
            case "ios":
            resourcesPath = AVersionPath
            default:
            fatalError("Unsupported platform \(atbuildPlatform)")
        }
        do {
            try FS.createDirectory(path: resourcesPath, intermediate: true)
        }
        catch SysError.FileExists { /* */ }
        catch { fatalError("\(error)")}
        for resource in resources {
            let dest = resourcesPath + Path(resource).basename()
            try! FS.copyItem(from: Path(resource), to: dest)
        }
        if atbuildPlatform == "ios" {
            try! FS.copyItem(from: Path(infoPlist), to: AVersionPath.appending("Info.plist"))
        }

        if atbuildPlatform == "osx" {
            try! FS.symlinkItem(from: relativeAVersionPath + "Resources", to: frameworkPath + "Resources")
        }
        //codesign
        let cmd = "codesign --force --deep --sign - --timestamp=none '\(AVersionPath)'"
        if system(cmd) != 0 {
            fatalError("Codesign failed.")
        }

        if compress {
            guard let packageVersion = env("ATBUILD_PACKAGE_VERSION") else {
                fatalError("No package version / ATBUILD_PACKAGE_VERSION")
            }
            let tarxz = "bin/\(name)-\(packageVersion).tar.xz"
            //detect compression level
            let fc: Bool
            if env("ATBUILD_CONFIGURATION_FAST_COMPILE")=="1" {
                fc = true
            } else { fc = false}
            let compressionLevel = fc ? "0" :"9"
            let cmd = "tar c --options \"xz:compression-level=\(compressionLevel)\" -Jf \(tarxz) bin/\(name).framework -C bin"
            if system(cmd) != 0 {
                fatalError("compress failed")
            }
        }
    }
}

PackageFramework().run()