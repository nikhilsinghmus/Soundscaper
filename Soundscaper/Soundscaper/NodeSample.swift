//
//  NodeSample.swift
//  Soundscaper
//
//  Created by Nikhil Singh on 10/23/17.
//  Copyright © 2017 Nikhil Singh. All rights reserved.
//

import Foundation
import AudioKit
import SceneKit

struct NodeSample {
    var node: SCNNode?
    var particleSystem: SCNParticleSystem?
    var player: AKAudioPlayer?
    var amp: Double = 0 {
        didSet {
            particleSystem?.birthRate = CGFloat(amp * 150)
            player?.volume = amp
        }
    }
    
    init(_ scnnode: SCNNode?, _ scnparticleSystem: SCNParticleSystem?, _ audioPlayer: AKAudioPlayer?) {
        node = scnnode
        particleSystem = scnparticleSystem
        player = audioPlayer
    }
}
