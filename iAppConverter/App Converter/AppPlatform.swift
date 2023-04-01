//
//  ConversionParameters.swift
//  iAppConverter
//
//  Created by Nitin Seshadri on 1/21/22.
//

import Foundation

struct AppPlatform: Equatable {
    
    var name: String
    var deviceFamilies: [Int]
    var buildPlatform: Int
    var cfSupportedPlatforms: [String]
    
    // Custom properties
    var architecture: String? = nil
    var deploymentTargetVersion: Float? = nil
    
}

struct AppPlatformKind {
    
    static func fromIndex(_ index: Int) -> AppPlatform {
        switch (index) {
        case 0:
            return ios
        case 1:
            return tvos
        case 2:
            return watchos
        case 3:
            return catalyst
        case 4:
            return catalystMacIdiom
        case 5:
            return iosSimulator
        case 6:
            return tvosSimulator
        case 7:
            return watchosSimulator
        default:
            return unknown
        }
    }
    
    // TODO: Add HomePod (not sure what the LC_BUILD_VERSION platform or CFBundleSupportedPlatforms for it is)
    // TODO: Add bridgeOS/TouchBar (not sure what the CFBundleSupportedPlatforms for it is)
    // TODO: Add realityOS (not sure what the CFBundleSupportedPlatforms for it is)
    
    static let ios = AppPlatform(name: "iOS or iPadOS", deviceFamilies: [1, 2], buildPlatform: 2, cfSupportedPlatforms: ["iPhoneOS"])
    static let tvos = AppPlatform(name: "tvOS", deviceFamilies: [3], buildPlatform: 3, cfSupportedPlatforms: ["AppleTVOS"])
    static let watchos = AppPlatform(name: "watchOS", deviceFamilies: [4], buildPlatform: 4, cfSupportedPlatforms: ["WatchOS"])
    static let catalyst = AppPlatform(name: "Mac Catalyst", deviceFamilies: [1, 2], buildPlatform: 6, cfSupportedPlatforms: ["MacOSX"])
    static let catalystMacIdiom = AppPlatform(name: "Catalyst Mac Idiom", deviceFamilies: [1, 2, 6], buildPlatform: 6, cfSupportedPlatforms: ["MacOSX"])
    static let iosSimulator = AppPlatform(name: "iOS or iPadOS Simulator", deviceFamilies: [1, 2], buildPlatform: 7, cfSupportedPlatforms: ["iPhoneSimulator"])
    static let tvosSimulator = AppPlatform(name: "tvOS Simulator", deviceFamilies: [3], buildPlatform: 8, cfSupportedPlatforms: ["AppleTVSimulator"])
    static let watchosSimulator = AppPlatform(name: "watchOS Simulator", deviceFamilies: [4], buildPlatform: 9, cfSupportedPlatforms: ["WatchSimulator"])
    static let unknown = AppPlatform(name: "Unknown", deviceFamilies: [], buildPlatform: -1, cfSupportedPlatforms: [])
}

struct ConversionParameters {
    
    var inputAppType: AppPlatform
    var outputAppType: AppPlatform
    
    var inputAppPath: URL
    var outputAppPath: URL
    
    var bundleIdentifier: String? = nil
    
    var dryRun: Bool = true
    
    var unquarantineWhenDone: Bool = true // recommended to stop Gatekeeper checks
    
}
