//
//  AppConverter.swift
//  iAppConverter
//
//  Created by Nitin Seshadri on 1/22/22.
//

import Foundation

struct AppConverterWarning {
    var title: String
    var explanatoryText: String
}

enum AppConverterError: LocalizedError {
    case parseError(_ filename: String, reason: String)
    case toolNotFound(_ path: String)
    case notImplementedYet(_ feature: String)

    var errorDescription: String? {
        switch self {
        case .parseError(let filename, _):
            return "Could not parse “\(filename)”"
        case .toolNotFound:
            return "Command-Line Tool Not Found"
        case .notImplementedYet(let feature):
            return feature
        }
    }
    
    var failureReason: String? {
        switch self {
        case .parseError(_, let reason):
            return reason
        case .toolNotFound(let path):
            return "Could not find the command-line tool located at “\(path)”."
        case .notImplementedYet:
            return "This is not implemented yet. Conversion will fail."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .parseError:
            return nil // You cannot recover from this error.
        case .toolNotFound:
            return "Make sure that you have Xcode or the Command-Line Tools installed.\n\nIf you do not have either of these, you can install the Command-Line Tools with\nxcode-select --install"
        case .notImplementedYet:
            return nil // You cannot recover from this error.
        }
    }
        
        
}

class AppConverter: NSObject {
    
    // MARK: Instance Variables
    
    private var parameters: ConversionParameters
    private var outputAppProperties: AppPlatform
    
    public weak var delegate: AppConverterDelegate?
    
    public private(set) var isConverting: Bool = false
    
    // MARK: Instance Methods
    
    override init() {
        fatalError("Use init(parameters:) instead")
    }
    
    init(parameters: ConversionParameters) {
        self.parameters = parameters
        self.outputAppProperties = parameters.outputAppType
        
        print(outputAppProperties)
        
        super.init()
    }
    
    public func start() {
        isConverting = true
        
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                delegate?.converterDidBeginConverting(self, dryRun: parameters.dryRun)
                
                delegate?.converter(self, didUpdateStep: "Deleting old conversion artifacts.")
                if ((parameters.outputAppPath != parameters.inputAppPath) && FileManager.default.fileExists(atPath: parameters.outputAppPath.path)) {
                    try FileManager.default.removeItem(at: parameters.outputAppPath)
                }
                
                delegate?.converter(self, didUpdateStep: "Copying app bundle to output path.")
                try FileManager.default.copyItem(at: parameters.inputAppPath, to: parameters.outputAppPath)
                
                delegate?.converter(self, didUpdateStep: "Processing Info.plist.")
                try processInfoPlist(infoPlistURL(for: parameters.outputAppPath))
            
                delegate?.converter(self, didUpdateStep: "Modifying Mach-O headers.")
                try modifyMachHeader(of: binaryURL(for: parameters.outputAppPath))
                
                if (outputAppProperties.name.lowercased().contains("watch")) {
                    delegate?.converter(self, didUpdateStep: "Packaging app for watchOS.")
                    
                    let warning = AppConverterWarning(
                        title: "Packaging UIKit App for watchOS",
                        explanatoryText: """
                        Some points to consider when converting your UIKit app to work on watchOS (please read before clicking OK):
                        - This has only been tested on the simulator. It will probably work on a real device, but I haven't fully worked out the steps yet.
                        - You will need to copy any bundle resources your app uses (e.g. Storyboards) into the WatchKitExtension.appex bundle in PlugIns. This is because the executable that runs is the one in the extension bundle. The WatchKit App executable is not used or checked in the simulator.
                        - On a real device, you cannot replace the WatchKit App stub executable, use install_name_tool to replace SockPuppetGizmo, etc. watchOS now seems to check that the stub executable links against SockPuppetGizmo (and possibly that it is signed by Apple as well).
                        - Storyboards are supported, but you must initialize your UIWindow in code. See tutorials online on how to do this.
                        - SceneKit (UIScene, UIWindowScene, etc.) is not available on watchOS. Use the AppDelegate instead.
                        - Make sure your AppDelegate has a UIWindow property named "window", or your app will crash on launch.
                        """
                    )
                    delegate?.converter(self, hasWarning: warning)
                    
                    try repackageBundleForWatchOS(at: parameters.outputAppPath)
                } else if (outputAppProperties.name.lowercased().contains("catalyst")) {
                    // TODO: Support repackaging and rewriting dylib paths for Catalyst apps.
                    delegate?.converter(self, didUpdateStep: "Packaging app for Mac Catalyst.")
                    
                    try repackageBundleForMacCatalyst(at: parameters.outputAppPath)
                }
                
                delegate?.converter(self, didUpdateStep: "Signing bundle.")
                try codesignBundle(at: parameters.outputAppPath)
                
                if (parameters.unquarantineWhenDone) {
                    delegate?.converter(self, didUpdateStep: "Unquarantining bundle.")
                    try unquarantineBundle(at: parameters.outputAppPath)
                }
                
                delegate?.converterDidFinishConverting(self, outputURL: parameters.outputAppPath)
            } catch(let error) {
                print(error)
                
                delegate?.converter(self, didEncounterError: error)
            }
        }
    }
    
    public func stop() {
        isConverting = false
    }
    
    // MARK: Private Methods
    
    private func infoPlistURL(for bundleURL: URL) -> URL {
        return bundleURL.appendingPathComponent("Info.plist")
    }
    
    private func infoPlistDictionary(for bundleURL: URL) throws -> NSDictionary {
        let infoPlistURL = infoPlistURL(for: bundleURL)
        let infoPlist: NSDictionary = try NSDictionary(contentsOf: infoPlistURL, error: ())
        return infoPlist
    }
    
    private func binaryURL(for bundleURL: URL) throws -> URL {
        let infoPlist: NSDictionary = try infoPlistDictionary(for: bundleURL)
        guard let executableName = infoPlist["CFBundleExecutable"] as? String else {
            throw AppConverterError.parseError(infoPlistURL(for: bundleURL).lastPathComponent, reason: "There is no entry for CFBundleExecutable.")
        }
        let executableURL = bundleURL.appendingPathComponent(executableName)
        
        return executableURL
    }
    
    private func processInfoPlist(_ infoPlistURL: URL) throws {
        let infoPlist: NSMutableDictionary = try NSMutableDictionary(contentsOf: infoPlistURL, error: ())
        
        infoPlist["LSRequiresIPhoneOS"] = (outputAppProperties.buildPlatform == AppPlatformKind.catalyst.buildPlatform) ? false : true
        
        if (outputAppProperties.cfSupportedPlatforms.count > 0) {
            infoPlist["CFBundleSupportedPlatforms"] = outputAppProperties.cfSupportedPlatforms
        }
        
        if let deploymentTargetVersion = outputAppProperties.deploymentTargetVersion {
            infoPlist["MinimumOSVersion"] = String(deploymentTargetVersion)
        } else {
            if let minimumOSVersionString = infoPlist["MinimumOSVersion"] as? String {
                if let minimumOSVersion = NumberFormatter().number(from: minimumOSVersionString)?.floatValue {
                    if (outputAppProperties.name.lowercased().contains("watch")) {
                        
                        // A non-watchOS app is being converted to a watchOS app.
                        // Subtract 7.0 from the MinimumOSVersion because watchOS versions are typically 7.0 less than their corresponding iOS version.
                        var watchMinimumOSVersion = minimumOSVersion - 7.0
                        
                        if (watchMinimumOSVersion == 8.2) {
                            // If equal to 8.2, bump the minimum OS version to 8.3 because of this really nice explanation from the simulator.
                            // This is why watchOS 8.2 doesn't exist.
                            /*
                             The bundle at "(path)" declares a MinimumOSVersion of 8.2, but watch apps targeting version 8.2 or 8.2.x are no longer supported. Versions in the 8.2 series were used for the first release of watchOS and its follow-on minor updates. Those watchOS versions only supported WatchKit 1.0 apps, which are no longer supported on modern watchOS. Modern watchOS 8.1 was followed by watchOS 8.3, and version 8.2 was not used again.
                             */
                            NSLog("Bumping MinimumOSVersion to 8.3.")
                            watchMinimumOSVersion += 0.1
                        }
                        
                        infoPlist["MinimumOSVersion"] = String(watchMinimumOSVersion)
                        
                        outputAppProperties.deploymentTargetVersion = watchMinimumOSVersion
                        
                        if (watchMinimumOSVersion >= 9.0) {
                            // If 9.0 or newer, create a single-target watchOS app.
                            infoPlist["WKApplication"] = true
                            infoPlist["WKWatchOnly"] = true
                        } else {
                            infoPlist["WKWatchKitApp"] = true
                        }
                        
                        infoPlist.removeObject(forKey: "LSRequiresIPhoneOS")

                    } else {
                        outputAppProperties.deploymentTargetVersion = minimumOSVersion
                    }
                }
            }
        }
        
        if (outputAppProperties.deviceFamilies.count > 0) {
            infoPlist["UIDeviceFamily"] = outputAppProperties.deviceFamilies
        }
        
        infoPlist.removeObject(forKey: "DTSDKName")
        infoPlist.removeObject(forKey: "DTSDKBuild")
        infoPlist.removeObject(forKey: "DTCompiler")
        infoPlist.removeObject(forKey: "DTPlatformBuild")
        infoPlist.removeObject(forKey: "DTPlatformVersion")
        infoPlist.removeObject(forKey: "DTXcode")
        infoPlist.removeObject(forKey: "DTXcodeBuild")
        infoPlist.removeObject(forKey: "DTPlatformName")
        
        print(infoPlist)
        
        if (!parameters.dryRun) {
            try infoPlist.write(to: infoPlistURL)
        }
    }
    
    private func modifyMachHeader(of binaryURL: URL) throws {
        
        let process = Process()
        
        let toolPath = "/usr/bin/vtool"
        
        if (!FileManager.default.fileExists(atPath: toolPath)) {
            throw AppConverterError.toolNotFound(toolPath)
        }
        
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var argv: [String] = []
        if let arch = outputAppProperties.architecture {
            argv.append(contentsOf: ["-arch", arch])
        }
        
        argv.append(contentsOf: ["-set-build-version", "\(outputAppProperties.buildPlatform)", "\(outputAppProperties.deploymentTargetVersion ?? 0.0)", "\(outputAppProperties.deploymentTargetVersion ?? 0.0)"])
                    
        argv.append(contentsOf: ["-replace", "-output", binaryURL.path, binaryURL.path])
        
        process.arguments = argv
        
        print(String(describing: process.arguments))
        
        if (!parameters.dryRun) {
            try process.run()
            process.waitUntilExit()
        }
    }
    
    private func repackageBundleForWatchOS(at bundleURL: URL) throws {
        if let deploymentTargetVersion = outputAppProperties.deploymentTargetVersion {
            if (deploymentTargetVersion >= 9.0) {
                // If the watchOS deployment target is 9.0 or newer, create a single-target watchOS app.
                // This becomes a no-op.
                return
            }
        }
        
        // Create _WatchKitStub directory and copy the executable to it
        let stubExecutableURL = bundleURL.appendingPathComponent("_WatchKitStub").appendingPathComponent("WK")
        
        try FileManager.default.createDirectory(atPath: stubExecutableURL.deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
        
        if (!parameters.dryRun) {
            try FileManager.default.copyItem(at: binaryURL(for: bundleURL), to: stubExecutableURL)
        }
        
        // Create WatchKit extension bundle and copy the executable to it
        let extensionExecutableURL = bundleURL.appendingPathComponent("PlugIns").appendingPathComponent("WatchKitExtension.appex").appendingPathComponent(try binaryURL(for: bundleURL).lastPathComponent)
        
        try FileManager.default.createDirectory(atPath: extensionExecutableURL.deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
        
        if (!parameters.dryRun) {
            try FileManager.default.copyItem(at: binaryURL(for: bundleURL), to: extensionExecutableURL)
            
            // Copy Base.lproj, if it exists
            try? FileManager.default.copyItem(at: bundleURL.appendingPathComponent("Base.lproj"), to:  extensionExecutableURL.deletingLastPathComponent().appendingPathComponent("Base.lproj"))
            
            // Copy Assets.car, if it exists
            try? FileManager.default.copyItem(at: bundleURL.appendingPathComponent("Assets.car"), to:  extensionExecutableURL.deletingLastPathComponent().appendingPathComponent("Assets.car"))
        }
        
        let infoPlist: NSDictionary = try infoPlistDictionary(for: bundleURL)
        
        let extensionInfoPlist: NSMutableDictionary = try NSMutableDictionary(contentsOf: Bundle.main.url(forResource: "WatchKitExtensionInfoTemplate", withExtension: "plist")!, error: ())
        
        extensionInfoPlist["CFBundleName"] = "WatchKitExtension"
        
        extensionInfoPlist["CFBundleSupportedPlatforms"] = infoPlist["CFBundleSupportedPlatforms"]
        
        extensionInfoPlist["CFBundleExecutable"] = extensionExecutableURL.lastPathComponent
        
        extensionInfoPlist["MinimumOSVersion"] = infoPlist["MinimumOSVersion"]
        
        extensionInfoPlist["CFBundleIdentifier"] = "\(infoPlist["CFBundleIdentifier"]!).watchkitextension"
        
        extensionInfoPlist["CFBundleDisplayName"] = infoPlist["CFBundleDisplayName"]
        
        extensionInfoPlist["NSExtension"] =
        ["NSExtensionAttributes" : ["WKAppBundleIdentifier" : infoPlist["CFBundleIdentifier"]],
         "NSExtensionPointIdentifier" : "com.apple.watchkit"]
        
        print(extensionInfoPlist)
        
        if (!parameters.dryRun) {
            try extensionInfoPlist.write(to: extensionExecutableURL.deletingLastPathComponent().appendingPathComponent("Info.plist"))
        }
    }
    
    private func repackageBundleForMacCatalyst(at bundleURL: URL) throws {
        // Not implemented yet.
        
        throw AppConverterError.notImplementedYet("Packaging App for Mac Catalyst")
    }
    
    private func dumpEntitlements(for binaryURL: URL) throws -> URL {
        
        let entitlementsPlistURL = FilesHelper.uniqueTemporaryDirectory.appendingPathComponent("Entitlements-\(binaryURL.deletingPathExtension().lastPathComponent).plist")
        
        let process = Process()
        
        let toolPath = "/usr/bin/codesign"
        
        if (!FileManager.default.fileExists(atPath: toolPath)) {
            throw AppConverterError.toolNotFound(toolPath)
        }
        
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var argv: [String] = []
        
        // TODO: On macOS Monterey and newer, we should specify that we want XML format with the --xml flag instead of a colon.
        argv.append(contentsOf: ["-d", "--entitlements", ":\(entitlementsPlistURL.path)"])
                    
        argv.append(binaryURL.path)
        
        process.arguments = argv
        
        print(String(describing: process.arguments))
        
        print(entitlementsPlistURL.path)
        
        if (!parameters.dryRun) {
            try process.run()
            process.waitUntilExit()
        }
        
        return entitlementsPlistURL
    }
    
    private func codesignBundle(at bundleURL: URL) throws {
        
        let entitlementsPlistURL = try dumpEntitlements(for: binaryURL(for: bundleURL))
        
        let process = Process()
        
        let toolPath = "/usr/bin/codesign"
        
        if (!FileManager.default.fileExists(atPath: toolPath)) {
            throw AppConverterError.toolNotFound(toolPath)
        }
        
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var argv: [String] = []
        
        argv.append(contentsOf: ["-s", "-", "--force", "--deep"])
        
        argv.append(contentsOf: ["--entitlements", entitlementsPlistURL.path, "--timestamp=none"])
                    
        argv.append(bundleURL.path)
        
        process.arguments = argv
        
        print(String(describing: process.arguments))
        
        if (!parameters.dryRun) {
            try process.run()
            process.waitUntilExit()
        }
    }
    
    private func unquarantineBundle(at bundleURL: URL) throws {
        
        let process = Process()
        
        let toolPath = "/usr/bin/xattr"
        
        if (!FileManager.default.fileExists(atPath: toolPath)) {
            throw AppConverterError.toolNotFound(toolPath)
        }
        
        process.executableURL = URL(fileURLWithPath: toolPath)
        
        var argv: [String] = []
        
        argv.append(contentsOf: ["-rd", "com.apple.quarantine"])
                    
        argv.append(bundleURL.path)
        
        process.arguments = argv
        
        print(String(describing: process.arguments))
        
        if (!parameters.dryRun) {
            try process.run()
            process.waitUntilExit()
        }
    }
}
