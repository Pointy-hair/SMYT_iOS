//================================================================================
//  CLChallenge is a subclass of AVObject
//  Class name: Challenge
//  Author: Xujie Song
//  Copyright (c) 2015 SK8 PTY LTD. All rights reserved.
//================================================================================

import Foundation

public class CLChallenge : AVObject, AVSubclassing {
    
    // ================================================================================
    // Constructors
    // ================================================================================
    
    public class func parseClassName() -> String! {
        return "Challenge"
    }
    
    private override init() {
        super.init();
    }
    
    public init(challengeId: String) {
        super.init();
//        self.objectId = challengeId;
    }
    
    public init(name: String, requirement: String, numberOfVerifyRequired: Int) {
        super.init();
        self.name = name;
        self.requirement = requirement;
        self.numberOfVerifyRequired = numberOfVerifyRequired;
    }
    
    // ================================================================================
    // Class properties
    // ================================================================================
    
    // ================================================================================
    // Shelf Methods
    // ================================================================================
    
    // ================================================================================
    // Property setters and getters
    // ================================================================================
    
    @NSManaged public dynamic var name: String!
    @NSManaged internal(set) dynamic var serial: Int    //Serial is generated by server, make it readonly.
    @NSManaged public dynamic var requirement: String!
    @NSManaged public dynamic var numberOfVerifyRequired: Int   //Default is 2 on server setting.
    @NSManaged public dynamic var coverImage: AVFile
    
    // ================================================================================
    // Export class
    // ================================================================================
    
}
