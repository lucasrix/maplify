//
//  StaticMap.swift
//  Maplify
//
//  Created by Evgeniy Antonoff on 4/8/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Foundation

let kStaticMapDefaultZoom = 13

class StaticMap: NSObject {
    
    class func staticMapUrl(latitude: Double, longitude: Double, sizeWidth: Int) -> NSURL {
        let host = "http://maps.googleapis.com/maps/api/staticmap?"
        let coordinate = "center=\(latitude),\(longitude)"
        let size = "&size=\(sizeWidth)x\(sizeWidth)"
        let zoom = "&zoom=\(kStaticMapDefaultZoom)"
        return NSURL(string: host + coordinate + size + zoom)!
    }
}
