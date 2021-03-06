//
//  DIscoverStoryPointTableDataSource.swift
//  Maplify
//
//  Created by Evgeniy Antonoff on 4/4/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import UIKit

let kTableViewHeaderFooterHeightMin: CGFloat = 0.0001

protocol DiscoverTableDataSourceDelegate {
    func discoverTableDidScroll(scrollView: UIScrollView)
}

class DiscoverTableDataSource: CSBaseTableDataSource {
    var profileView: ProfileView! = nil
    var scrollDelegate: DiscoverTableDataSourceDelegate! = nil

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellData = self.activeModel.cellData(indexPath)
        let model = cellData.model
        
        if model is DiscoverItem {
            let item = model as! DiscoverItem
            return self.configureDiscoverItemCell(item, tableView: tableView, indexPath: indexPath)
        } else if model is String {
            let cell = tableView.dequeueReusableCellWithIdentifier(String(DiscoverPlaceholderCell), forIndexPath: indexPath) as! DiscoverPlaceholderCell
            cell.configure(cellData)
            return cell
        }
        return UITableViewCell()
    }
    
    func configureDiscoverItemCell(item: DiscoverItem, tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        let cellData = self.activeModel.cellData(indexPath)
        if item.type ==  DiscoverItemType.StoryPoint.rawValue {
            let cell = tableView.dequeueReusableCellWithIdentifier(String(DiscoverStoryPointCell), forIndexPath: indexPath) as! DiscoverStoryPointCell
            cell.configure(cellData)
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier(String(DiscoverStoryCell), forIndexPath: indexPath) as! DiscoverStoryCell
            cell.configure(cellData)
            return cell
        }
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let cellData = self.activeModel.cellData(indexPath)
        let model = cellData.model
        if model is DiscoverItem {
            let item = model as! DiscoverItem
            return self.heightForDiscoverItem(item, cellData: cellData)
        } else if model is String {
            return DiscoverPlaceholderCell.contentSize(cellData).height
        }
        return 0
    }
    
    func heightForDiscoverItem(item: DiscoverItem, cellData: CSCellData) -> CGFloat {
        var itemHeight: CGFloat = 0
        if item.type == DiscoverItemType.StoryPoint.rawValue {
            itemHeight = DiscoverStoryPointCell.contentSize(cellData).height
        } else if item.type ==  DiscoverItemType.Story.rawValue {
            itemHeight = DiscoverStoryCell.contentSize(cellData).height
        }
        return itemHeight
    }
    
    func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if let cellData = self.activeModel.cellData(indexPath) {
            let model = cellData.model
            if model is DiscoverItem {
                let item = model as! DiscoverItem
                if (item.type == DiscoverItemType.StoryPoint.rawValue) && (cell is DiscoverStoryPointCell) {
                    (cell as! DiscoverStoryPointCell).cellDidEndDiplaying()
                }
            }
        }
    }
    
    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return self.profileView
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return (self.profileView != nil) ? self.profileView.contentHeight() : kTableViewHeaderFooterHeightMin
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return kTableViewHeaderFooterHeightMin
    }
    
    //MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(scrollView: UIScrollView) {
        self.scrollDelegate?.discoverTableDidScroll(scrollView)
    }
}
