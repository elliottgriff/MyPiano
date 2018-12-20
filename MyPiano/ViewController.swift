//
//  ViewController.swift
//  MyPiano
//
//  Created by elliott on 9/21/18.
//  Copyright © 2018 Elliott Griffin. All rights reserved.
//

import UIKit
import AudioKit
import AudioKitUI

class ViewController: UIViewController, AKKeyboardDelegate {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func noteOn(note: MIDINoteNumber) {
        do {
            try midiSample.play(noteNumber: note, velocity: 100, channel: 0)
        } catch {
            print("cannot play note")
        }
    }
    
    func noteOff(note: MIDINoteNumber) {
        do {
            try midiSample.stop(noteNumber: note, channel: 0)
        } catch {
            print("cannot stop note")
        }
    }
    
    var midiSample = AKMIDISampler()
    var recorder: AKNodeRecorder!
    var player: AKPlayer!
    var tape = try! AKAudioFile()
    var mix = AKMixer()
    public var numberOfRecordings:Int = 0
    public var outputFile: AVAudioFile?
    public var keyboardView: Keyboard?
    public var recordings: Recordings?
    let keyboardy = Keyboard(width: 1,
                            height: 0,
                            firstOctave: 2,
                            octaveCount: 1)
    
    
    var state = State.readyToRecord
    
    @IBOutlet private weak var infoLabel: UILabel!
    @IBOutlet private weak var resetButton: UIButton!
    @IBOutlet private weak var recButton: UIButton!
    
    @IBOutlet weak var octaveUp: UIButton!
    @IBOutlet weak var octaveDown: UIButton!
    
    
    enum State {
        case readyToRecord
        case recording
        case readyToPlay
        case playing
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        AKAudioFile.cleanTempDirectory()
        
        AKSettings.bufferLength = .medium
        
        do {
            try AKSettings.setSession(category: .playAndRecord, with: .allowBluetoothA2DP)
        } catch {
            AKLog("Could not set session category.")
        }
        
        AKSettings.defaultToSpeaker = true
        AKSettings.audioInputEnabled = true
        
        do {
            try midiSample.loadMelodicSoundFont("gpiano", preset: 0)
        } catch {
            print("error playing")
        }
        
        let reverb = AKReverb(midiSample)
        reverb.loadFactoryPreset(.mediumRoom)
        mix = AKMixer(reverb)
        
        recorder = try? AKNodeRecorder(node: mix)
        
        if let file = recorder.audioFile {
            AKSettings.defaultToSpeaker = true
            player = AKPlayer(audioFile: file)
            AudioKit.output = player
//            AudioKit.output = AKMixer(player, mix)
//            recorder = try! AKNodeRecorder(node: mix, file: tape)
        }
        
        player.isLooping = true
        player.completionHandler = playingEnded
        
        AudioKit.output = mix

        do {
            try AudioKit.start()
        } catch {
            AKLog("AudioKit did not start!")
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
//        setupButtonNames()
        setupUIForRecording()
        setupKeyboardUI()
        
//        keyboardView?.firstOctave = 1
        
    }
    
    
    func playingEnded() {
        DispatchQueue.main.async {
            self.setupUIForPlaying ()
        }
    }
    
    //MARK:  Buttons
    
    @IBAction func upOctavePress(_ sender: UIButton) {
        if keyboardy.firstOctave == 6 {
            print("it's over 9,000!")
        } else {
            keyboardy.firstOctave += 1
        }
        
    }
    
    @IBAction func downOctavePressed(_ sender: UIButton) {
        if keyboardy.firstOctave == 0 {
            print("the Tao is like water...")
        } else {
            keyboardy.firstOctave += -1
        }
        
    }
    
    
    @IBAction func recButtonTouched(sender: UIButton) {
        switch state {
        case .readyToRecord :
            recButton.setTitle("STOP", for: .normal)
            state = .recording
            do {
                try recorder.record()
            } catch {
                AKLog("Error recording")
            }
            

            
        case .recording :
            if let tape = recorder.audioFile {
                player.load(audioFile: tape)
            }
            
            if let _ = player.audioFile?.duration {
                recorder.stop()
                

                
                
                tape.exportAsynchronously(name: "temp.caf",
                                          baseDir: .temp,
                                          exportFormat: .caf) {_, exportError in
                                            if let error = exportError {
                                                AKLog("Export Failed \(error)")
                                            } else {
                                                AKLog("Export succeeded")
                                            }
                }
//                saveFile()
                setupUIForPlaying()
            }
        case .readyToPlay :
            player.play()
            recButton.setTitle("STOP", for: .normal)
            state = .playing
            
        case .playing :
            player.stop()
            setupUIForPlaying()

        }
    }
    
    
    struct Constants {
        static let empty = ""
    }
    
    
    func setupButtonNames() {
        recButton.setTitle(Constants.empty, for: UIControl.State.disabled)
    }
    
    func setupUIForRecording () {
        state = .readyToRecord
        infoLabel.text = "0.0"
        recButton.setTitle("RECORD", for: .normal)
        resetButton.isHidden = false
        resetButton.isEnabled = true
    }
    
    func setupUIForPlaying () {
        let recordedDuration = player != nil ? player.audioFile?.duration  : 0
        infoLabel.text = "\(String(format: "%0.01f", recordedDuration!)) sec."
        recButton.setTitle("PLAY", for: .normal)
        state = .readyToPlay
        resetButton.isHidden = false
        resetButton.isEnabled = true
    }
    
    @IBAction func resetButtonTouched(sender: UIButton) {
        player.stop()
//        try! recorder.reset()
        clearTmpDir()
//        do {
//            try recorder.reset()
//        } catch { AKLog("Errored resetting.") }
        
//        AKAudioFile.cleanTempDirectory()
        

        setupUIForRecording()
    }
    
    //Get Directory Path
    func getDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        return documentDirectory
    }
//
//    //Display Alerts
    func displayAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "dismiss", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func saveFile() {
        
//        try! AudioKit.start()
        numberOfRecordings += 1
        let fileName = getDirectory().appendingPathComponent("\(numberOfRecordings).wav")
        let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        
        //            start recording
        
        outputFile = try! AVAudioFile(forWriting: fileName, settings: settings)
        try! AudioKit.renderToFile(outputFile!, duration: self.player.duration, prerender: {
            self.player.play()
        })
        
        outputFile = try! AVAudioFile(forWriting: fileName, settings: settings)
        try! AudioKit.renderToFile(outputFile!, duration: self.player.duration, prerender: {
            self.player.play()
        })
        
        UserDefaults.standard.set(numberOfRecordings, forKey: "myNumber")
        recordings?.myTableView.reloadData()
        
    }
    

    
    public func setupKeyboardUI() {
        let keyboard = keyboardy
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(keyboard)
        let keyboardYconstraint = NSLayoutConstraint(item: keyboard, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1.20, constant: 0)
        let keyboardHeightConstraint = NSLayoutConstraint(item: keyboard, attribute: .height, relatedBy: .equal, toItem: self.view, attribute: .height, multiplier: 0.80, constant: 0)
        let keyboardWidthConstraint = NSLayoutConstraint(item: keyboard, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1.01, constant: 0)
        
        
        keyboard.delegate = self
        keyboard.polyphonicMode = true
        NSLayoutConstraint.activate([keyboardYconstraint, keyboardHeightConstraint, keyboardWidthConstraint])
    }
    
    func clearTmpDir(){
        
        var removed: Int = 0
        do {
            let tmpDirURL = URL(string: NSTemporaryDirectory())!
            let tmpFiles = try FileManager.default.contentsOfDirectory(at: tmpDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            print("\(tmpFiles.count) temporary files found")
            for url in tmpFiles {
                removed += 1
                try FileManager.default.removeItem(at: url)
            }
            print("\(removed) temporary files removed")
        } catch {
            print(error)
            print("\(removed) temporary files removed")
        }
    }
}




