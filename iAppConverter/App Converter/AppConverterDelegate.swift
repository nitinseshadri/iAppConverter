//
//  AppConverterDelegate.swift
//  iAppConverter
//
//  Created by Nitin Seshadri on 1/22/22.
//

import Foundation

protocol AppConverterDelegate: NSObject {
    func converterDidBeginConverting(_ converter: AppConverter, dryRun: Bool)
    func converter(_ converter: AppConverter, didUpdateProgress progress: Double)
    func converter(_ converter: AppConverter, didUpdateStep step: String)
    func converterDidFinishConverting(_ converter: AppConverter, outputURL: URL)
    func converter(_ converter: AppConverter, hasWarning warning: AppConverterWarning)
    func converter(_ converter: AppConverter, didEncounterError error: Error)
}
