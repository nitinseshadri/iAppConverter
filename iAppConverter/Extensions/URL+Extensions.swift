//
//  URL+Extensions.swift
//  iAppConverter
//
//  Created by Nitin Seshadri on 1/21/22.
//

import Foundation
import UniformTypeIdentifiers

extension URL {
    
    var isAppBundle: Bool {
        get {
            return self.pathExtension == "app"
        }
    }
    
}
