//
//  ViewController.swift
//  iAppConverter
//
//  Created by Nitin Seshadri on 1/20/22.
//

import Cocoa
import UniformTypeIdentifiers

class ViewController: NSViewController, NSOpenSavePanelDelegate {
    
    // MARK: IBOutlets
    
    @IBOutlet weak var inputAppTypeButton: NSPopUpButton?
    @IBOutlet weak var outputAppTypeButton: NSPopUpButton?
    
    @IBOutlet weak var forceArchCheckbox: NSButton?
    @IBOutlet weak var archTextField: NSTextField?
    
    @IBOutlet weak var forceDeviceFamilyCheckbox: NSButton?
    @IBOutlet weak var deviceFamilyTextField: NSTextField?
    
    @IBOutlet weak var forceBuildPlatformCheckbox: NSButton?
    @IBOutlet weak var buildPlatformTextField: NSTextField?
    
    @IBOutlet weak var changeBundleIdentifierCheckbox: NSButton?
    @IBOutlet weak var bundleIdentifierTextField: NSTextField?
    
    @IBOutlet weak var unquarantineCheckbox: NSButton?
    
    @IBOutlet weak var dryRunCheckbox: NSButton?
    
    @IBOutlet weak var inputPathTextField: NSTextField?
    @IBOutlet weak var inputPathBrowseButton: NSButton?
    
    @IBOutlet weak var outputPathTextField: NSTextField?
    @IBOutlet weak var outputPathBrowseButton: NSButton?
    
    // MARK: View Controller methods
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    // MARK: IBActions
    
    @IBAction func startConversion(_ sender: Any) {
        
        let construction = constructConversionParameters()
        
        if (!construction.successful || construction.parameters == nil) {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Could not begin conversion"
            if let error = construction.error {
                alert.informativeText = error
            } else {
                alert.informativeText = "An unknown error occurred."
            }
            alert.runModal()
            return
        }
        
        if let controller = storyboard?.instantiateController(withIdentifier: "ConvertViewController") as? ConvertViewController {
            NSLog("Will begin conversion with parameters: \(String(describing: construction.parameters))")
            
            controller.parameters = construction.parameters
            presentAsSheet(controller)
        } else {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Could not begin conversion"
            alert.informativeText = "There was a problem opening the conversion view."
            alert.runModal()
            return
        }
    }
    
    @IBAction func quitApp(_ sender: Any) {
        NSLog("User requested quit, quitting now.")
        NSApp.terminate(self)
    }
    
    // MARK: Open/Save Panels
    
    @IBAction func browseForInputPath(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.beginSheetModal(for: view.window!) { response in
            switch(response) {
            case .OK:
                self.inputPathTextField?.stringValue = panel.url?.path ?? ""
                break
            default:
                break
            }
        }
    }
    
    @IBAction func browseForOutputPath(_ sender: Any) {
        let panel = NSSavePanel()
        panel.delegate = self
        panel.beginSheetModal(for: view.window!) { response in
            switch(response) {
            case .OK:
                self.outputPathTextField?.stringValue = panel.url?.path ?? ""
                break
            default:
                break
            }
        }
    }
    
    // MARK: NSOpenSavePanelDelegate

    func panel(_ sender: Any, userEnteredFilename filename: String, confirmed okFlag: Bool) -> String? {
        if let savePanel = sender as? NSSavePanel {
            if (okFlag) {
                if let selectedSaveURL = savePanel.directoryURL?.appendingPathComponent(filename) {
                    if (selectedSaveURL.isAppBundle) {
                        return filename
                    } else {
                        let alert = NSAlert()
                        alert.alertStyle = .critical
                        alert.messageText = "Invalid file name"
                        alert.informativeText = "The file name should be an app bundle or end in .app."
                        alert.runModal()
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: Construct ConversionParameters struct
    
    func constructConversionParameters() -> (successful: Bool, error: String?, parameters: ConversionParameters?) {
        var error: String = ""
        
        let inputAppType: AppPlatform = AppPlatformKind.fromIndex(inputAppTypeButton?.indexOfSelectedItem ?? -1)
        let outputAppType: AppPlatform = AppPlatformKind.fromIndex(outputAppTypeButton?.indexOfSelectedItem ?? -1)
        
        var architecture: String? = nil
        if (forceArchCheckbox?.state == .on) {
            architecture = archTextField?.stringValue ?? ""
        }
        
        var deviceFamilies: [Int]? = nil
        if (forceDeviceFamilyCheckbox?.state == .on) {
            deviceFamilies = []
            
            if let deviceFamilyTextFieldContents = deviceFamilyTextField?.stringValue {
                for familyComponent in deviceFamilyTextFieldContents.components(separatedBy: ",") {
                    if let family = Int(familyComponent) {
                        if (!deviceFamilies!.contains(family)) {
                            deviceFamilies!.append(family)
                        }
                    }
                }
                
                for familyComponent in deviceFamilyTextFieldContents.components(separatedBy: ", ") {
                    if let family = Int(familyComponent) {
                        if (!deviceFamilies!.contains(family)) {
                            deviceFamilies!.append(family)
                        }
                    }
                }
            }
            
            print(deviceFamilies!)
        }
        
        var buildPlatform: Int? = nil
        if (forceBuildPlatformCheckbox?.state == .on) {
            if let buildPlatformTextFieldContents = buildPlatformTextField?.stringValue {
                buildPlatform = Int(buildPlatformTextFieldContents)
            }
        }
        
        var bundleIdentifier: String? = nil
        if (changeBundleIdentifierCheckbox?.state == .on) {
            bundleIdentifier = bundleIdentifierTextField?.stringValue ?? ""
        }
        
        let unquarantineWhenDone: Bool = (unquarantineCheckbox?.state == .on) ? true : false
        
        let dryRun: Bool = (dryRunCheckbox?.state == .on) ? true : false
        
        var inputAppPath: URL
        if let inputPath = inputPathTextField?.stringValue {
            if !inputPath.isEmpty {
                if (FileManager.default.fileExists(atPath: inputPath)) {
                    let inputURL = URL(fileURLWithPath: inputPath)
                    if (inputURL.isAppBundle) {
                        inputAppPath = inputURL
                        
                        var outputAppPath: URL = inputAppPath
                        if let outputPath = outputPathTextField?.stringValue {
                            if !outputPath.isEmpty {
                                let outputURL = URL(fileURLWithPath: outputPath)
                                if (outputURL.isAppBundle) {
                                    outputAppPath = outputURL
                                } else {
                                    error = "The output path should be an app bundle."
                                }
                            } else {
                                NSLog("The output path is empty.")
                            }
                        } else {
                            NSLog("The output path is not valid.")
                        }
                        
                        if error.isEmpty {
                            var parameters = ConversionParameters(inputAppType: inputAppType, outputAppType: outputAppType, inputAppPath: inputAppPath, outputAppPath: outputAppPath, unquarantineWhenDone: unquarantineWhenDone)
                            
                            parameters.dryRun = dryRun
                            
                            if let architecture = architecture {
                                parameters.outputAppType.architecture = architecture
                            }
                            
                            if let deviceFamilies = deviceFamilies {
                                parameters.outputAppType.deviceFamilies = deviceFamilies
                            }
                            
                            if let buildPlatform = buildPlatform {
                                parameters.outputAppType.buildPlatform = buildPlatform
                            }
                            
                            if let bundleIdentifier = bundleIdentifier {
                                parameters.bundleIdentifier = bundleIdentifier
                            }
                            
                            return (true, nil, parameters)
                        }
                    } else {
                        error = "The input path should be an app bundle."
                    }
                } else {
                    error = "No app bundle exists at the provided input path."
                }
            } else {
                error = "The input path is empty."
            }
        } else {
            error = "The input path is not valid."
        }
        
        return (false, error, nil)
    }
    
}

