pragma solidity^0.4.18;

contract getRooms {

  uint NB_ROOMS = 2;
  uint NB_TIMESLOTS = 2;
  uint MAXIMUM_BIDS = 5;

   struct biddingInfos {
       uint endTime;
       uint highestBid;
       uint secondHighestBid;
       address bidder;
       bool initialized;
   }

   uint[] public rooms;
   address admin;
   uint time = 180;
   mapping (uint => address) RoomSlotToStudentMapping;
   mapping (uint => biddingInfos) RoomToBiddingMap;
   mapping(address => uint) StudentToAssignedRooms;
   mapping(address => uint) StudentNumberOfBidding;

   function getRooms() public {
     /* Initialize the rooms */
      for (uint roomNb = 0; roomNb < NB_ROOMS; roomNb++) {
        for (uint slotNb = 0; slotNb < NB_TIMESLOTS; slotNb++) {
          /* Room 101  is first room on the first timeslot */
          rooms.push((roomNb + 1) * 100 + slotNb + 1);
        }
        RoomSlotToStudentMapping[rooms[roomNb]] = msg.sender;
      }
      //admin is issuer of contract
      admin = msg.sender;
   }
}

contract RoomAuction is getRooms {

    // ethereum wallet needs older solidity vers. and has old syntax for constructor
    modifier isAdmin() {
      require(msg.sender == admin);
      _;
    }

    modifier isntAdmin() {
        require(msg.sender != admin);
        _;
    }

    modifier canBid(uint _roomSlot) {
        // Auction isn't over
        require(RoomToBiddingMap[_roomSlot].endTime > now);

        // Room is initialized
        require(RoomToBiddingMap[_roomSlot].initialized == true);

        // Amount is an integer

        // The value is high enough
        require(uint(msg.value) > RoomToBiddingMap[_roomSlot].highestBid);

        // The student hasn't reached the limit for this auction
        // require(StudentNumberOfBidding[msg.sender] < MAXIMUM_BIDS);
        _;
    }

    modifier isntRunning() {
        require(now > RoomToBiddingMap[rooms[0]].endTime);
        _;
    }

    // get Admin of the auction
    function adminAdress() public view returns(address) {
        return(admin);
    }

    function fix_time(uint _time) isAdmin() public {
        time = _time;
    }

    function timeValue() public view returns (uint) {
      return (time);
    }

    // open up next biding round (only Admin able to)
    function resetBidding() public isAdmin() {
        // Time of the auction
        uint reset = now + time;
        for(uint k = 0; k < rooms.length; k++){
            //initate values in biddingInfos
            address bidder = RoomToBiddingMap[rooms[k]].bidder;
            StudentToAssignedRooms[bidder] = 0;
            RoomToBiddingMap[rooms[k]] = biddingInfos(reset, 0, 0, msg.sender, true);
            RoomSlotToStudentMapping[rooms[k]] = msg.sender;
      }
    }

    // bidding function
    function inputBid(uint _roomSlot) public canBid(_roomSlot) isntAdmin() payable  {

        // send back token to the to the previous bidder
        RoomToBiddingMap[_roomSlot].bidder.transfer(RoomToBiddingMap[_roomSlot].highestBid);

        // assign new values to biddingInfos
        RoomToBiddingMap[_roomSlot].secondHighestBid = RoomToBiddingMap[_roomSlot].highestBid;
        RoomToBiddingMap[_roomSlot].highestBid = msg.value;
        RoomToBiddingMap[_roomSlot].bidder = msg.sender;

        // Increment the number of bids
        StudentNumberOfBidding[msg.sender]++;
    }

    // See which is currently the highest bid for a specific room
    function highestBid(uint _roomSlot) public view returns(uint, address,uint){
        return (RoomToBiddingMap[_roomSlot].highestBid,
        RoomToBiddingMap[_roomSlot].bidder,
        RoomToBiddingMap[_roomSlot].endTime);
    }

    // Assign rooms to winners
    function assignRoomSlots() public isAdmin() isntRunning() {
        // Loop trough all rooms which were actually bidded & slots and assign each
        for(uint j = 0; j < rooms.length; j++){
            // Check if room was bidded (admin is not longer owner)
            if(RoomSlotToStudentMapping[rooms[j]] != RoomToBiddingMap[rooms[j]].bidder) {
                address bidder = RoomToBiddingMap[rooms[j]].bidder;
                RoomSlotToStudentMapping[rooms[j]] = bidder;
                StudentToAssignedRooms[bidder]++;

                // Transfer highest bidding to the admin
                msg.sender.transfer(RoomToBiddingMap[rooms[j]].highestBid);
            }
        }
    }

    function whichRoom() view external isntAdmin() returns (uint[]) {
        uint[] memory roomsAffected = new uint[](StudentToAssignedRooms[msg.sender]);
        uint affected = 0;
        for (uint roomNb = 0; roomNb < rooms.length; roomNb++) {
            if (RoomToBiddingMap[rooms[roomNb]].bidder == msg.sender) {
                roomsAffected[affected] = rooms[roomNb];
                affected++;
            }
        }
        return (roomsAffected);
    }

    // add function to retrieve booked rooms
    function roomsAssigned(uint _roomSlot) public view returns (string, uint, uint){
      if (RoomSlotToStudentMapping[_roomSlot] == msg.sender) {
        uint room_number = _roomSlot / 100;
        uint time_slot = _roomSlot % 100;
        return ("You have been assigned ", room_number, time_slot);
      } else {
        return ("No Rooms have been assigned to you", 0, 0);
      }
    }

    function flush() public isAdmin() isntRunning() {
        msg.sender.transfer(address(this).balance);
    }
}
