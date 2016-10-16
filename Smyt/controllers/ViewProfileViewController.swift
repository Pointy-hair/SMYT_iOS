//
//  ProfileViewController.swift
//  Challenger
//
//  Created by SongXujie on 4/01/2016.
//  Copyright © 2016 SK8 PTY LTD. All rights reserved.
//

import Foundation
import FBSDKLoginKit
import AVFoundation
import APParallaxHeader
import FBSDKShareKit
import MessageUI

class ViewProfileViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MFMailComposeViewControllerDelegate,APParallaxViewDelegate, ProfileCustomHeaderViewProtocol, HomeVideoTableViewCellProtocol /*, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, settingsViewProtocol*/ {
    
    var user: CLUser!
    
    
    @IBOutlet weak var tableView: UITableView!
    
    var videoArray = [CLVideo]();
//    var videoItemArray = [AVPlayerItem]();
    var playerArray = [AVPlayer]();
    
    //For paging
    var currentPage = 0;
    var currentRegisteredCell : HomeVideoTableViewCell?;
    weak var currentCell: HomeVideoTableViewCell!;
    
    var refreshControl = UIRefreshControl();
    
    var isLoadingMoreVideos = true;
    
    //Inputs
    let numbeOfVideoPerReload = 5;
    let numberOfVideoPreloadRequired = 1;
    let isThumbnailShowing = true;
    var isLoadingContinuously = true;
    let isVideoCaching = true;
    var isFirstTimeAppear = true;
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        self.refreshControl.backgroundColor = UIColor.whiteColor();
        self.refreshControl.tintColor = UIColor.cyanColor();
        self.refreshControl.addTarget(self, action: Selector("refreshVideos"), forControlEvents: UIControlEvents.ValueChanged);
        self.tableView.addSubview(self.refreshControl);
        
        self.currentPage = 0;
        self.isLoadingContinuously = !CL.isNotAutoLoading;
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(true);
        
        //move to view did will appear?
        if (self.user != nil) {
            NSLog("init with user\(self.user)");
            self.initWithUser(self.user);
        } else {
            if let user = CL.currentUser {
                self.initWithUser(user);
            } else {
                
                //The root controller - TabController, will take care of the login
                return;
            }
            
        }
        
        if (self.isFirstTimeAppear){
            self.isFirstTimeAppear = false;
            self.reloadVideos();
            
        }
        self.playCurrentVideo();
        
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(true);
        self.scrollViewDidScroll(self.tableView);
    }
    
    func refreshVideos() {
        self.currentPage = 0;
        self.videoArray = [CLVideo]();
        self.playerArray = [AVPlayer]();
        self.tableView.reloadData();
        self.reloadVideos();
    }
    
    func reloadVideos() {
        
        CL.stampTime();
        
        let query = CLVideo.query();
        query.whereKey("status", equalTo: CLVideo.STATUS.LISTING);
        query.whereKey("owner", equalTo: self.user);
        query.cachePolicy = .NetworkElseCache;
        query.includeKey("challenge");
        query.includeKey("owner");
        query.includeKey("thumbNailImage");
        query.includeKey("file");
        query.limit = self.numbeOfVideoPerReload;
        query.skip = self.currentPage * self.numbeOfVideoPerReload;
        
        query.orderByDescending("createdAt");
        query.whereKey("isSuccessVideo", equalTo: true);
        
        query.findObjectsInBackgroundWithBlock { (downloadArray, error) -> Void in
            if let e = error {
                CL.showError(e);
            } else {
                
//                CL.logWithTimeStamp("Video Objs downloaded.");
//                CL.stampTime();
                
                //If at initial page, remove all preious resources
                if (self.currentPage == 0) {
                    self.videoArray = [CLVideo]();
                    self.playerArray = [AVPlayer]();
                }
                
                //Insert downloaded video objects
                for (var i = 0; i < downloadArray.count; i++) {
                    
                    //Kepp a reference of i, as position
                    //This is a muct, as it is required by the async task below. DO NOT REMOVE
                    let index = self.currentPage * self.numbeOfVideoPerReload + i
                    
                    let video = downloadArray[i] as! CLVideo;
                    NSLog("videoArray insert video at index \(index) count \(self.videoArray.count)");
                    self.videoArray.insert(video, atIndex: index);
                    
                    CL.stampTime();
                    
                    //add an placeholder item to array, to be replaced by async task below. DO NOT REMOVE
                    let url = NSURL(string: (video.file?.url!)!);
                    let placeholderItem = AVPlayerItem(URL: url!);
                    
                    NSLog("video array count: \(self.videoArray.count)");
                    self.playerArray.insert(AVPlayer(playerItem: placeholderItem), atIndex: index);
                    self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: UITableViewRowAnimation.Automatic);
                    
                    //Cache video
                    if (self.isVideoCaching) {
                        
                        //Check potential cached file
                        CL.stampTime();
                        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0];
                        let file = cachesDirectory.stringByAppendingString(video.objectId + ".mp4");
                        let videoCacheData = NSData(contentsOfFile: file)
                        if  (videoCacheData != nil) {
                            let videoSize = Float(videoCacheData!.length)/1024.0/1024.0;
                            //Video already cached
                            //Re-init videoItem from file system. (This is crucial for fast 'replaceCurrentItem'
                            let fileURL = NSURL(fileURLWithPath: file);
                            let asset = AVAsset(URL: fileURL);
                            
                            //Initialize pre-buffered videoItem
                            let videoItem = AVPlayerItem(asset: asset);
                            
                            //Replace non-buffered playItem with newly pre-buffered playItem
                            self.playerArray[index] = AVPlayer(playerItem: videoItem);
                            
//                            CL.logWithTimeStamp("Cached video item loaded, Size: \(videoSize) MB");
                        } else {
                            //Video not cached
                            //Initialize per-buffered playItem for faster loading
                            let asset = AVURLAsset(URL: url!);
                            asset.loadValuesAsynchronouslyForKeys(["duration"], completionHandler: { () -> Void in
                                //Initialize pre-buffered videoItem
                                let videoItem = AVPlayerItem(asset: asset);
                                
                                //Replace non-buffered playItem with newly pre-buffered playItem
                                self.playerArray[index] = AVPlayer(playerItem: videoItem);
                                
//                                CL.logWithTimeStamp("URL video item loaded");
                            });
                            
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
                                let urlString = video.file!.url!;
                                if let videoData = NSData(contentsOfURL: NSURL(string: urlString)!) {
                                    
                                    //Store in filesystem
                                    videoData.writeToFile(file, atomically: true);
                                    
//                                    CL.logWithTimeStamp("Video \(index) downloaded and stored");
                                    
                                    //Re-init videoItem from file system. (This is crucial for fast 'replaceCurrentItem'
                                    let videoSize = Float(videoData.length)/1024.0/1024.0;
                                    let fileURL = NSURL(fileURLWithPath: file);
                                    let asset = AVAsset(URL: fileURL);
                                    
                                    //Initialize pre-buffered videoItem
                                    let videoItem = AVPlayerItem(asset: asset);
                                    
                                    //Replace non-buffered playItem with newly pre-buffered playItem
                                    self.playerArray[index] = AVPlayer(playerItem: videoItem);
                                    
//                                    CL.logWithTimeStamp("Cached video item loaded, Size: \(videoSize) MB");
                                } else {
//                                    CL.logWithTimeStamp("Failed to cache video data \(urlString)");
                                }
                            });
                        }
                    } else {
                        //Initialize per-buffered playItem for faster loading
                        let asset = AVURLAsset(URL: url!);
                        asset.loadValuesAsynchronouslyForKeys(["duration"], completionHandler: { () -> Void in
                            //Initialize pre-buffered videoItem
                            let videoItem = AVPlayerItem(asset: asset);
                            
                            //Replace non-buffered playItem with newly pre-buffered playItem
                            self.playerArray[index] = AVPlayer(playerItem: videoItem);
                            
//                            CL.logWithTimeStamp("URL video item loaded");
                        });
                    }
                }
                
                //End refershing
                self.refreshControl.endRefreshing();
                self.isLoadingMoreVideos = false;
                if (self.currentPage == 0) {
                    self.tableView.scrollRectToVisible(CGRectMake(0, 0, 1, 1), animated: true);
                }
            }
        }
    }
    
    func loadMoreVideos() {
        if (self.isLoadingMoreVideos) {
            return;
        } else {
            self.currentPage += 1;
            self.isLoadingMoreVideos = true;
            self.reloadVideos();
            NSLog("Reloading video, page \(self.currentPage)");
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (self.isLoadingContinuously) {
            NSLog("number of rows: \(self.videoArray.count)");
            return self.videoArray.count;
        } else {
            NSLog("number of rows: \(self.videoArray.count+1)");
            return self.videoArray.count + 1;
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        //Check for load more button
        if (self.isLoadingContinuously == false) {
            if (indexPath.row == self.videoArray.count) {
                let cell = self.tableView.dequeueReusableCellWithIdentifier("loadMoreCell", forIndexPath: indexPath);
                return cell;
            }
        }
        
        //Load cell for video
        let cell = self.tableView.dequeueReusableCellWithIdentifier("videoTableViewCell", forIndexPath: indexPath) as! HomeVideoTableViewCell;
        cell.captionTextView.textContainer.maximumNumberOfLines = 3;
        cell.captionTextView.textContainer.lineBreakMode = NSLineBreakMode.ByTruncatingTail;
        cell.captionTextView.contentInset = UIEdgeInsetsMake(-5, 0, 0, 0);
        cell.delegate = self;
        //Get corresponding video
        
        //The following settings is only applied for non-initial cell
        let video = self.videoArray[indexPath.row];
        cell.video = video;
        
        let player = self.playerArray[indexPath.row];
        
        //Show loading animation
        //        cell.avLayer.hidden = true;
        cell.activityIndicator.startAnimating();
        
        //Add notification
        //Make sure avplayer layer is displayed after video finished buffering, specifically 1/1000 after current time seconds
        if let currentTime = player.currentItem?.currentTime() {
            let timeToAdd = CMTimeMakeWithSeconds(1, 1000)
            let observeTime = CMTimeAdd(currentTime, timeToAdd);
            player.addBoundaryTimeObserverForTimes([NSValue(CMTime: observeTime)], queue: nil, usingBlock: { () -> Void in
                //remove observer
            })
        } else {
            //Cell is loading a new video, reset the time to zero
            //Make sure avplayer layer is displayed after video finished buffering, specifically 1/1000 seconds
            player.addBoundaryTimeObserverForTimes([NSValue(CMTime: CMTimeMake(1, 1000))], queue: nil, usingBlock: { () -> Void in
                //remove observer
            })
        }
        player.actionAtItemEnd = .None;
        
        //Item replaced, safely show the player
        cell.activityIndicator.stopAnimating();
        //        cell.avLayer.hidden = false;
        cell.videoPlayer = player;
        
        //Play the first video
        var shoulldInitiallyPlay = false;
        if (indexPath.row == 0) {
            self.currentRegisteredCell = cell;
            shoulldInitiallyPlay = true;
        } else {
            shoulldInitiallyPlay = false;
        }
        
        //For Manual Loading, need to load image here
        if (self.isThumbnailShowing) {
            if let urlString = video.thumbNailImage?.url {
                let url = NSURL(string: urlString);
                //                CL.stampTime();
                cell.videoThumbnailView.sd_setImageWithURL(url, placeholderImage: UIImage());
            }
            
        }
        
        cell.avLayer = AVPlayerLayer(player: cell.videoPlayer);
        let width = UIScreen.mainScreen().bounds.width;
        cell.avLayer.frame = CGRectMake(0, 0, width, width);
        cell.videoThumbnailView.layer.addSublayer(cell.avLayer);
        cell.videoThumbnailView.clipsToBounds = true;
        //Add tap gesture
        let tap0 = UITapGestureRecognizer(target: cell, action: Selector("handleVideoTap"));
        tap0.delegate = cell;
        cell.videoThumbnailView.addGestureRecognizer(tap0);
        
        let tap1 = UITapGestureRecognizer(target: cell, action: Selector("handleUserTap"));
        tap1.delegate = cell;
        cell.userProfileImage.addGestureRecognizer(tap1);
        cell.userProfileName.addGestureRecognizer(tap1);
        
        
        //Autoplay the first item
        if shoulldInitiallyPlay {
            NSNotificationCenter.defaultCenter().addObserver(cell, selector: "videoLoop", name:AVPlayerItemDidPlayToEndTimeNotification, object: cell.videoPlayer!.currentItem);
            cell.avLayer.hidden = false;
            cell.videoPlayer!.play();
            NSLog("showing video hiding thumbnail for initial play");
        }
        
        cell.userProfileName.text = video.owner?.profileName;
        cell.captionTextView.text = video.caption;
        //self.captionTextView.sizeToFit();
        //self.challengeLabel.text = video.challenge?.name;
        
        //Setting time
        //self.videoUploadTimeLabel.text = self.video.createdAt.formattedAsTimeAgo();
        
        //Check for verify state
        if (CL.currentUser != nil) {
            CL.currentUser.hasVerifiedVideoWithBlock(cell.video) { (verified, error) -> () in
                if (verified) {
                    cell.verifyButton.setImage(UIImage(named: "icon_like_1"), forState: .Normal);
                } else {
                    cell.verifyButton.setImage(UIImage(named: "icon_like_0"), forState: .Normal);
                }
            }
        } else {
            //∂
        }
        
        if let owner = video.owner {
            if let img = owner.profileImage {
                cell.imageActivityIndicator.startAnimating();
                cell.userProfileImage.sd_setImageWithURL(NSURL(string: img.url), placeholderImage: UIImage(named: "default_profile")) { (image, error, cacheType, url) -> Void in
                    if let e = error {
                        NSLog("set profile image error");
                        CL.showError(e);
                    } else {
                        NSLog("profile image set successful");
                    }
                    cell.imageActivityIndicator.stopAnimating();
                }
            }
        }
        
        //Set the video data
        cell.likeButton.setTitle(" \(cell.video.numberOfVerify) likes", forState: .Normal);
        cell.commentButton.setTitle(" \(cell.video.numberOfComment) comment", forState: .Normal);
        cell.shareButton.setTitle(" \(cell.video.numberOfView) View", forState: .Normal);
        
        //Increment number of views, since it's been viewed
        cell.video.incrementKey("numberOfView");
        cell.video.saveEventually();
        
        return cell;
        
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        //Check if should load mor video for continuous loading
        //Note, do not reload for cell 0, as it's the initial cell
        if (self.isLoadingContinuously && indexPath.row != 0) {
            if (self.videoArray.count - indexPath.row == self.numberOfVideoPreloadRequired) {
                //When there's less than 3 videos left, load more videos
                self.loadMoreVideos();
            }
        }
    }
    
    
    //When Scrolling
    func scrollViewDidScroll(scrollView: UIScrollView) {
        
        if let tempCell = self.currentRegisteredCell {
            self.videoNotificationUnregister(tempCell);
        }
        
        if let indexPaths = self.tableView.indexPathsForVisibleRows{
            for path in indexPaths {
                if let cell = self.tableView.cellForRowAtIndexPath(path) as? HomeVideoTableViewCell {
                    //nil check here is IMPORTANT, videoPlayer initialization is a async process and it is possible to product nil when initializing
                    if (cell.videoPlayer != nil) {
                        cell.videoPlayer!.pause();
                        self.playerArray[path.row] = cell.videoPlayer!;
                        //NSLog("display thumbnail, hide player when scrolling)");
                        cell.avLayer.hidden = true;
                        cell.activityIndicator.startAnimating();
                    }
                }
            }
        }
        
        
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if (indexPath.row == self.videoArray.count) {
            return 64.0;
        } else {
            return 160 + UIScreen.mainScreen().bounds.width;
        }
    }
    
    //For Manual Loading, load objects upon click
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        //In case of manual reload, instead of isLoadingContinuously
        if (indexPath.row == self.videoArray.count) {
            //Load more clicked
            self.loadMoreVideos();
        }
    }
    
    //Combine end decelerating and end dragging
    //DidEndDragging is always called, there're however 2 cases
    //1. EndDrag, ScrollView stopped immediately(decelerate = false)
    //2. EndDrag, ScrollView kept scrolling
    //Case 1. Use DidEndDragging to play current item
    //Case 2. Use DidEndDecelerating to wait, and then to play current item
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        if (!decelerate){
            self.playCurrentVideo();
        }
        
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        
        self.playCurrentVideo();
    }
    
    //Play current video
    func playCurrentVideo() {
        
        CL.stampTime();
        if (self.refreshControl.hidden && self.videoArray.count != 0) {
            let indexPaths = self.tableView.indexPathsForVisibleRows;
            
            //Setting the video and play
            self.currentCell = self.getMostVisibleCell(indexPaths);
            
            self.currentCell.videoPlayer!.play();
            self.currentCell.activityIndicator.stopAnimating();
            self.currentCell.avLayer.hidden = false;
            
            self.videoNotificationRegister(self.currentCell);
            
            CL.logWithTimeStamp("Video start playing");
        } else {
            NSLog("Video array is empty");
        }
    }
    
    //Function to check most visible cell on screen
    func getMostVisibleCell (indexPaths: [NSIndexPath]?) -> HomeVideoTableViewCell {
        //temp vars determining feasible cell to play
        var maxHeight = Float(0.0);
        var mostVisibleIndexPath: NSIndexPath!;
        
        //Check which cell has the maximum area, and play it.
        for (var i = 0; i < indexPaths!.count; i++) {
            let indexPath = indexPaths![i];
            let cellRect = tableView.rectForRowAtIndexPath(indexPath)
            if let superview = tableView.superview {
                let convertedRect = tableView.convertRect(cellRect, toView:superview)
                let intersect = CGRectIntersection(tableView.frame, convertedRect)
                let visibleHeight = CGRectGetHeight(intersect)
                if (Float(visibleHeight) > maxHeight) {
                    maxHeight = Float(visibleHeight);
                    mostVisibleIndexPath = indexPath;
                }
            }
        }
        
        let cell = self.tableView.cellForRowAtIndexPath(mostVisibleIndexPath) as! HomeVideoTableViewCell;
        return cell;
    }
    
    //Delegate method for HomeVideoTableViewCellProtocol
    func presentViewController(VC: UIViewController) {
        //For iOS 8
        VC.providesPresentationContextTransitionStyle = true;
        VC.definesPresentationContext = true;
        VC.modalPresentationStyle = UIModalPresentationStyle.CurrentContext;
        self.presentViewController(VC, animated: true, completion: nil);
        
    }
    
    func commentButtonClicked(video: CLVideo) {
        self.performSegueWithIdentifier("segueToCommentsViewController", sender: video);
    }
    
    func goToProfile(user: CLUser) {
        //self.performSegueWithIdentifier("segueToProfile", sender: user);
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "segueToFollower"){
            let vc = segue.destinationViewController as! FollowingTableTableViewController;
            vc.isFollowing = false;
            vc.userToDisplay = self.user;
        }
        
        if (segue.identifier == "segueToFollowing"){
            let vc = segue.destinationViewController as! FollowingTableTableViewController;
            vc.isFollowing = true;
            vc.userToDisplay = self.user;
        }
        
        if (segue.identifier == "segueToCommentsViewController") {
            let VC = segue.destinationViewController as! CommentsViewController;
            VC.video = sender as! CLVideo;
        }
        
        if (segue.identifier == "segueToProfile") {
            let VC = segue.destinationViewController as! ViewProfileViewController;
            VC.user = sender as! CLUser;
            //            VC.initWithUser(sender as! CLUser);
        }
    }
    
    //Register and unregister from notification center
    func videoNotificationRegister(cell: HomeVideoTableViewCell) {
        //NSLog("Registering cell \(self.tableView.indexPathForCell(cell)?.row)");
        NSNotificationCenter.defaultCenter().addObserver(cell, selector: "videoLoop", name:AVPlayerItemDidPlayToEndTimeNotification, object: cell.videoPlayer!.currentItem);
        self.currentRegisteredCell = cell;
    }
    
    func videoNotificationUnregister(cell: HomeVideoTableViewCell) {
        //NSLog("Unregistering cell \(self.tableView.indexPathForCell(cell)?.row)");
        NSNotificationCenter.defaultCenter().removeObserver(cell, name: AVPlayerItemDidPlayToEndTimeNotification, object: cell.videoPlayer!.currentItem);
        self.currentRegisteredCell = nil;
    }
    
    
    
    func initWithUser(user: CLUser) {
        
        self.user = user;
        
        let customHeaderView = ProfileCustomHeaderView.init();
        
        customHeaderView.delegate = self;
        customHeaderView.initWithUser(user);
        self.tableView.addParallaxWithView(customHeaderView, andHeight: 190);
        NSLog("header view: \(self.view.bounds.width) \(customHeaderView.frame)"); 
        
    }
    
    func followerButtonClicked() {
        self.performSegueWithIdentifier("segueToFollower", sender: nil);
    }
    
    func followingButtonClicked() {
        self.performSegueWithIdentifier("segueToFollowing", sender: nil);
    }
    
    func selectProfileTab(){
        self.navigationController?.tabBarController?.performSegueWithIdentifier("segueToLogin", sender: nil);
    }
    
    
    
    @IBAction func backButtonClicked(sender: AnyObject) {
        self.navigationController?.popViewControllerAnimated(true);
    }
    
    //    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
    //        let requiredWidth = collectionView.bounds.size.width/2 - 10;
    //        let requiredHeight = requiredWidth;
    //        let requiredSize = CGSize(width: requiredWidth, height: requiredHeight);
    //
    //        return requiredSize;
    //    }
    
    //func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
    //<#code#>
    //}
    
    //    func setEstimatedSizeIfNeeded (){
    //        let flowLayout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout;
    //        let estimatedWidth:CGFloat = 130;
    //
    //        if (flowLayout.estimatedItemSize.width != estimatedWidth) {
    //            flowLayout.estimatedItemSize = CGSizeMake(estimatedWidth, 100);
    //            flowLayout.invalidateLayout();
    //        }
    //    }
    
    
    func shareButtonClicked(video: CLVideo) {
        //Share button
        if let url = video.file?.url {
            NSLog("Share button clicked displaying share dialog");
            NSLog("video url \(url)");
            NSLog("Thumbnail url \(video.thumbNailImage.url)");
            
            let content = FBSDKShareLinkContent();
            
            content.contentTitle = "Show me your talent";
            content.contentDescription = video.caption;
            content.contentURL = NSURL(string: url);
            content.imageURL = NSURL(string: video.thumbNailImage.url);
            let dialog = FBSDKShareDialog();
            dialog.mode = FBSDKShareDialogMode.FeedWeb;
            dialog.shareContent = content;
            dialog.fromViewController = self;
            dialog.show();
            
        } else {
            NSLog("Set share content error");
        }
    }
    
    func moreButtonClicked(video: CLVideo) {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController();
            mail.mailComposeDelegate = self;
            var email = "";
            var senderName = "";
            if let owner = video.owner {
                email = owner.email;
            }
            
            if let user = CL.currentUser {
                if let name = user.profileName {
                    senderName = name;
                }
            }
            
            mail.setToRecipients([email]);
            mail.setSubject("Feedback for SMYT video from " + senderName);
            //            mail.setMessageBody("Blabla", isHTML: false);
            self.presentViewController(mail, animated: true, completion: nil)
        } else {
            CL.promote("Please setup the mailbox on the phone to continue");
        }
    }
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        switch result.rawValue {
//        case MFMailComposeResultCancelled.rawValue:
//            print("Cancelled");
//        case MFMailComposeResultSaved.rawValue:
//            print("Saved");
//        case MFMailComposeResultSent.rawValue:
//            print("Sent");
//        case MFMailComposeResultFailed.rawValue:
//            print("Error: \(error?.localizedDescription)");
        default:
            break
        }
        controller.dismissViewControllerAnimated(true, completion: nil);
    }
    
}
