//
//  ViewController.swift
//  Soundscaper
//
//  Copyright © 2017 Nikhil Singh. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import AudioKit
import ReplayKit
import MessageUI

struct NodePitch {
    var node: SCNNode?
    var pitch: Int?
    var particleSystem: SCNParticleSystem?
    var player: AKAudioPlayer?
    var amp: Double = 0 {
        didSet {
            particleSystem?.birthRate = CGFloat(amp * 150)
            player?.volume = amp
        }
    }
    
    init(_ scnnode: SCNNode?, _ midiPitch: Int, _ scnparticleSystem: SCNParticleSystem?, _ audioPlayer: AKAudioPlayer?) {
        node = scnnode
        pitch = midiPitch
        particleSystem = scnparticleSystem
        player = audioPlayer
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    var nodes: [NodePitch] = [NodePitch(nil, 0, nil, nil)]
    var minimum = 0
    var index = 0
    
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey : AVVideoCodecType.h264,
                                                                            AVVideoWidthKey : UIScreen.main.bounds.size.width,
                                                                            AVVideoHeightKey : UIScreen.main.bounds.size.height])
    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    let micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    let recorder = RPScreenRecorder.shared()
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("\(Date().timeIntervalSince1970).mov".replacingOccurrences(of: " ", with: "_"))
    var assetWriter: AVAssetWriter!
    
    let microphone = AKMicrophone()
    var freqTracker: AKFrequencyTracker?
    let string = AKPluckedString()
    let saw = AKOscillatorBank(waveform: AKTable(.sawtooth, phase: 0, count: 16384))
    var nodeRecorder: AKNodeRecorder?
    var file: AKAudioFile?
    
    
    lazy var callback = AKPeriodicFunction(frequency: 2, handler: {
        
//        self.index = ((self.index + 1) >= self.nodes.count) ? self.minimum : self.index + 1
        
        self.checkAmps()
//        let amp = self.nodes[self.index].amp
//        let pitch = self.nodes[self.index].pitch
//
//        if let pitch = pitch, pitch > 0 {
////            self.string.trigger(frequency: pitch.midiNoteToFrequency(), amplitude: Double(amp * 20))
////            self.saw.play(noteNumber: MIDINoteNumber(pitch), velocity: MIDIVelocity(max(amp * 127, 80)))
//        }
//        
//        DispatchQueue.main.async {
//            if let node = self.nodes[self.index].node {
//                UIView.animate(withDuration: 0.5, animations: {
//                    (node.geometry as! SCNSphere).radius = 0.05
//                })
//            }
//        }
//        
//        let deadlineTime = DispatchTime.now() + 0.05
//        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
//            if let node = self.nodes[self.index].node {
//                UIView.animate(withDuration: 0.5, animations: {
//                    (node.geometry as! SCNSphere).radius = 0.01
//                })
//            }
//            
//            self.saw.stop(noteNumber: MIDINoteNumber(pitch!))
//        }
    })
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print(error)
        }
        
        assetWriter = try! AVAssetWriter(url: url, fileType: .mov)
        
        saw.attackDuration = 0.001
        saw.decayDuration = 0.02
        saw.sustainLevel = 0.5
        saw.releaseDuration = 0.1
        
        // SceneKit
        sceneView.delegate = self
        sceneView.showsStatistics = false
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Gesture Recognizers
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(removeNode(_:)))
        view.addGestureRecognizer(swipe)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(stopRecording(_:)))
        view.addGestureRecognizer(pinch)
        
        // AudioKit
        if let inputs = AudioKit.inputDevices {
            do {
                try AudioKit.setInputDevice(inputs[0])
                try microphone.setDevice(inputs[0])
            } catch {
                print(error)
            }
        }
        
        let mic = AKBooster(microphone)
        freqTracker = AKFrequencyTracker(mic, hopSize: 200, peakCount: 2_000)
        microphone.start()
        freqTracker?.start()
        
        let silence = AKBooster(freqTracker, gain: 0)
        AudioKit.output = silence
        AudioKit.output = saw
        
        AudioKit.start(withPeriodicFunctions: callback)
        callback.start()
        
        // Screen Recording
        [videoInput, audioInput, micInput].forEach { assetWriter.add($0) }
        videoInput.expectsMediaDataInRealTime = true
        recorder.isMicrophoneEnabled = true
        
        recorder.startCapture(handler: { cmbuf, bufType, error in
            if CMSampleBufferDataIsReady(cmbuf) {
                let cmtime = CMSampleBufferGetPresentationTimeStamp(cmbuf)

                if self.assetWriter.status == .unknown {
                    self.assetWriter.startWriting()
                    self.assetWriter.startSession(atSourceTime: cmtime)
                }

                if self.assetWriter.status == AVAssetWriterStatus.failed {
                    print("\(self.assetWriter.error!)")
                    return
                }

                switch bufType {
                case .video: if self.videoInput.isReadyForMoreMediaData { self.videoInput.append(cmbuf) }
                case .audioApp: if self.audioInput.isReadyForMoreMediaData { self.audioInput.append(cmbuf) }
                case .audioMic: if self.micInput.isReadyForMoreMediaData { self.micInput.append(cmbuf) }
                }
            }


        }, completionHandler: { error in
            print(error ?? "No Error")
        })
    }
    
    @objc func removeNode(_ gesture: UIGestureRecognizer) {
        let result = sceneView.hitTest(gesture.location(in: sceneView), options: [:])
        
        if result.count > 0 {
            nodes = nodes.filter { $0.node != result[0].node }
            result[0].node.removeFromParentNode()
        } else {
            if let nodepitch = nodes.popLast() {
                nodepitch.node?.removeFromParentNode()
            }
        }
    }
    
    func checkAmps() {
        for i in 0 ..< nodes.count {
            if let node = nodes[i].node, let camera = sceneView.session.currentFrame?.camera {
                nodes[i].amp = abs(1 - (abs(node.position.z - (camera.transform.columns.3.z)) - 0.5) * 2)
            }
        }
    }
    
    func hz2midi(_ frequency: Double) -> Int {
        guard frequency > 0 else { return 0 }
        return Int(round(69 + (12 * log2(frequency/440.0))))
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer) {
//        guard let currentFrame = sceneView.session.currentFrame else {
//            return
//        }
//
//        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.01))
//        let psys = SCNParticleSystem(named: "P1", inDirectory: nil)!
//        psys.emitterShape = SCNSphere(radius: 0.01)
//        sphereNode.addParticleSystem(psys)
//        sceneView.scene.rootNode.addChildNode(sphereNode)
//
//        var translation = matrix_identity_float4x4
//        translation.columns.3.z = -0.1
//        print(currentFrame.camera.transform)
//        sphereNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
//        sphereNode.localRotate(by: SCNQuaternion.init(1, 0, 0, 0))
//
//        nodes.append(NodePitch(sphereNode, hz2midi(freqTracker?.frequency ?? 440), psys))
//
//        let _: () = {
//            minimum = 1
//        }()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

extension ViewController: MFMailComposeViewControllerDelegate {
    @objc func stopRecording(_ gesture: UIGestureRecognizer) {
        recorder.stopCapture(handler: { error in
            debugPrint(error)
            
            self.assetWriter.finishWriting {
                let mcvc = MFMailComposeViewController()
                var fileData: Data?
                do {
                    try fileData = Data.init(contentsOf: self.url)
                } catch {
                    print(error)
                    return
                }
                
                print(fileData ?? "noData")
                
                DispatchQueue.main.async {
                    mcvc.mailComposeDelegate = self
                    mcvc.setMessageBody("Video from \(Date()).", isHTML: false)
                    mcvc.setSubject("Video!")
                    mcvc.setToRecipients(["nikhilsinghmus@gmail.com"])
                    mcvc.addAttachmentData(fileData!, mimeType: "video/quicktime", fileName: self.url.lastPathComponent)
                    self.present(mcvc, animated: true, completion: nil)
                }
            }
        })
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        do {
            file = try AKAudioFile()
            microphone.outputNode.removeTap(onBus: 0)
            nodeRecorder = try AKNodeRecorder(node: microphone, file: file)
            try nodeRecorder?.record()
        } catch {
            print(error)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        nodeRecorder?.stop()
        
        guard let file = file else { return }
        
        let player: AKAudioPlayer?
        do {
            player = try AKAudioPlayer(file: file)
            player?.looping = true
            AudioKit.output = player
            player?.play()
        } catch {
            print(error)
            return
        }
        
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.01))
        let psys = SCNParticleSystem(named: "P1", inDirectory: nil)!
        psys.emitterShape = SCNSphere(radius: 0.01)
        sphereNode.addParticleSystem(psys)
        sceneView.scene.rootNode.addChildNode(sphereNode)
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.1
        print(currentFrame.camera.transform)
        sphereNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
        sphereNode.localRotate(by: SCNQuaternion.init(1, 0, 0, 0))
        
        nodes.append(NodePitch(sphereNode, hz2midi(freqTracker?.frequency ?? 440), psys, player))
        
        let _: () = {
            minimum = 1
        }()
    }
}
