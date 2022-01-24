//
//  FilesHelper.swift
//  iAppConverter
//
//  Created by Nitin Seshadri on 10/6/21.
//

import Cocoa

class FilesHelper: NSObject {
    
    static let shared: FilesHelper = FilesHelper()
    
    static var documentsDirectory: String {
        get {
            NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        }
    }
    
    static var temporaryDirectory: URL {
        get {
            FileManager.default.temporaryDirectory
        }
    }
    
    static var uniqueTemporaryDirectory: URL {
        get {
            let directoryURL = FilesHelper.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            
            do {
                try FileManager.default.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
                return directoryURL
            } catch(let error) {
                print(error)
                
                NSLog("[FilesHelper] Could not create unique temporary directory at \(directoryURL), returning standard temporary directory instead. The error was: \(error.localizedDescription)")
                return FilesHelper.temporaryDirectory
            }
        }
    }
    
    /*
    static func openFileURLInFilesApp(_ fileURL: URL) {
        // Change the scheme of the URL to shareddocuments:// so that it'll open in the Files app
        var urlComponents = URLComponents(url: fileURL, resolvingAgainstBaseURL: true)
        #if !targetEnvironment(macCatalyst) // Only change the URL scheme on iOS/iPadOS
        urlComponents?.scheme = "shareddocuments" // URL scheme for Files app
        #endif
        let filesAppURL = urlComponents?.url ?? fileURL
        
        // Open the new URL
        UIApplication.shared.open(filesAppURL)
    }
     */
    
}

