//
//  ConvertViewController.swift
//  iAppConverter
//
//  Created by Nitin Seshadri on 1/21/22.
//

import Cocoa

class ConvertViewController: NSViewController, AppConverterDelegate {
    
    // MARK: IBOutlets
    
    @IBOutlet weak var convertingTitleLabel: NSTextField?
    @IBOutlet weak var convertingExplanatoryLabel: NSTextField?
    
    @IBOutlet weak var dryRunLabel: NSTextField!
    
    @IBOutlet weak var convertingProgressIndicator: NSProgressIndicator?
    
    @IBOutlet weak var cancelButton: NSButton?
    @IBOutlet weak var cancelingActivityIndicator: NSProgressIndicator?
    
    // MARK: Instance Variables
    
    var parameters: ConversionParameters? = nil
    
    var converter: AppConverter? = nil

    // MARK: View Controller methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        // Remove "Explanatory text will appear here" message.
        convertingExplanatoryLabel?.stringValue = ""
        
        // Hide "Dry Run" label.
        dryRunLabel?.isHidden = true
        
        guard let parameters = parameters else {
            fatalError("No parameter object was provided to the converter")
        }
        
        NSLog("Beginning conversion with parameters: \(String(describing: parameters))")
        
        converter = AppConverter(parameters: parameters)
        converter?.delegate = self
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        converter?.start()
    }
    
    func updateProgress(percentage: Double?, explanatoryText: String?, indeterminate: Bool?) {
        
        if let percentage = percentage {
            convertingProgressIndicator?.doubleValue = percentage
        }
        
        if let explanatoryText = explanatoryText {
            convertingExplanatoryLabel?.stringValue = explanatoryText
        }
        
        if let indeterminate = indeterminate {
            convertingProgressIndicator?.isIndeterminate = indeterminate
            if (indeterminate) {
                convertingProgressIndicator?.startAnimation(self)
            }
        }
    }
    
    // MARK: AppConverter delegate methods
    
    func converterDidBeginConverting(_ converter: AppConverter, dryRun: Bool) {
        DispatchQueue.main.async { [unowned self] in
            updateProgress(percentage: 0.0, explanatoryText: "Started conversion.", indeterminate: true)
            
            if (dryRun) {
                dryRunLabel?.isHidden = false
            }
        }
    }
    
    func converter(_ converter: AppConverter, didUpdateProgress progress: Double) {
        DispatchQueue.main.async { [unowned self] in
            updateProgress(percentage: progress, explanatoryText: nil, indeterminate: false)
        }
    }
    
    func converter(_ converter: AppConverter, didUpdateStep step: String) {
        DispatchQueue.main.async { [unowned self] in
            updateProgress(percentage: nil, explanatoryText: step, indeterminate: nil)
        }
    }
    
    func converterDidFinishConverting(_ converter: AppConverter, outputURL: URL) {
        DispatchQueue.main.async { [unowned self] in
            self.updateProgress(percentage: 100.0, explanatoryText: "Finishing up...", indeterminate: true)
            
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            
            dismiss(self)
        }
    }
    
    func converter(_ converter: AppConverter, hasWarning warning: AppConverterWarning) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = warning.title
            alert.informativeText = warning.explanatoryText
            alert.runModal()
        }
    }
    
    func converter(_ converter: AppConverter, didEncounterError error: Error) {
        DispatchQueue.main.async { [unowned self] in
            convertingTitleLabel?.stringValue = "Conversion Failed"
            
            updateProgress(percentage: 0.0, explanatoryText: "The error was: \(error.localizedDescription)", indeterminate: false)
            
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Conversion Failed"
            alert.informativeText = "The error was: \(error.localizedDescription)"
            alert.runModal()
            
            dismiss(self)
        }
    }
    
    
    // MARK: IBActions
    
    @IBAction func cancelAction(_ sender: Any) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Are you sure you want to cancel conversion?"
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Continue")
        alert.buttons[0].hasDestructiveAction = true
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
        let response = alert.runModal()
        
        switch(response) {
        case .alertFirstButtonReturn: // Cancel
            cancelButton?.isEnabled = false
            
            cancelingActivityIndicator?.startAnimation(sender)
            
            convertingTitleLabel?.stringValue = "Canceling..."
            
            convertingExplanatoryLabel?.stringValue = "Sorry to see you go!"
            
            convertingProgressIndicator?.isIndeterminate = true
            convertingProgressIndicator?.startAnimation(sender)
            
            DispatchQueue.main.async { [unowned self] in
                converter?.stop()
                
                converter = nil
                
                sleep(2)
                
                dismiss(self)
            }
            break
        default:
            break
        }
    }
    
}
