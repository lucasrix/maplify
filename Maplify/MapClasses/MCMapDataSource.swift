//
//  MCMapDataSource.swift
//  Maplify
//
//  Created by Sergey on 3/17/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Foundation

protocol MCMapDataSourceDelegate {
    func numberOfGroups() -> Int
    func numberOfMapItemsForGroup(groupIndex: Int) -> Int
    func mapItem(mapView: MCMapView, indexPath: NSIndexPath) -> MCMapItem
}

class MCMapDataSource {
    var mapView: MCMapView! = nil
    var mapService: MCMapService! = nil
    var mapActiveModel: MCMapActiveModel! = nil
    var delegate: AnyObject! = nil
    
    func reloadMapView<T: MCMapItem>(type: T.Type) {
        self.mapService.removeAllItems()
        
        print(self.mapActiveModel.numberOfSections())
        
        for i in 0...self.mapActiveModel.numberOfSections() - 1 {
            for j in 0...self.mapActiveModel.numberOfItems(i) - 1 {
                let indexPath = NSIndexPath(forRow: j, inSection: i)
                let data = self.mapActiveModel.cellData(indexPath)
                let mapItem = T()
                mapItem.configure(data)
                self.mapService.placeItem(mapItem)
            }
        }
    }
}