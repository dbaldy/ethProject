pragma solidity^0.4.18;

contract ERC20 {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    function approveAndCall(address _spender, uint256 _value, uint _extraData) public;
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

interface tokenRecipient { function receiveApproval(address _sender, uint256 _value, ERC20 _tokenContract, uint _roomSlot) external; }

contract RoomAuction is tokenRecipient {

    uint NB_ROOMS = 2;
    uint NB_TIMESLOTS = 2;
    uint MAXIMUM_BIDS = 5;
    address tracker_0x_address;

   struct biddingInfos {
       uint endTime;
       uint highestBid;
       uint secondHighestBid;
       address bidder;
       bool initialized;
   }

   uint[] public rooms;
   address admin;
   uint balance = 0;
   uint time = 180;
   mapping (uint => address) RoomSlotToStudentMapping;
   mapping (uint => biddingInfos) RoomToBiddingMap;
   mapping(address => uint) StudentToAssignedRooms;
   mapping(address => uint) StudentNumberOfBidding;

   function RoomAuction(address _tracker_0x_address) public {
       tracker_0x_address = _tracker_0x_address;
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

    // ethereum wallet needs versiojn 0.4.24 and has old syntax for constructor
    modifier isAdmin() {
      require(msg.sender == admin);
      _;
    }

    modifier isntAdmin() {
        require(msg.sender != admin);
        _;
    }

    modifier canBid(uint _roomSlot, uint tokens) {
        // Auction isn't over
        require(RoomToBiddingMap[_roomSlot].endTime > now);

        // Room is initialized
        require(RoomToBiddingMap[_roomSlot].initialized == true);

        // Amount is an integer

        // The value is high enough
        require(uint(tokens) > RoomToBiddingMap[_roomSlot].highestBid);

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
    // Respects Checks-Effects-Interaction pattern
    function inputBid(address _sender, uint _roomSlot, uint tokens) private canBid(_roomSlot, tokens) isntAdmin() {
        address oldBidder = RoomToBiddingMap[_roomSlot].bidder;
        uint oldHigestBid = RoomToBiddingMap[_roomSlot].highestBid;

        // assign new values to biddingInfos
        RoomToBiddingMap[_roomSlot].secondHighestBid = oldHigestBid;
        RoomToBiddingMap[_roomSlot].highestBid = tokens;
        RoomToBiddingMap[_roomSlot].bidder = _sender;

        // Increment the number of bids and adjust balance
        StudentNumberOfBidding[_sender]++;
        balance -= oldHigestBid;

        // send back token to the to the previous bidder
        if (oldHigestBid > 0) {
            ERC20(tracker_0x_address).transfer(oldBidder,oldHigestBid);
        }
    }

    // Non standard function
    // https://medium.com/@jgm.orinoco/ethereum-smart-service-payment-with-tokens-60894a79f75c
    function receiveApproval(address _sender, uint256 _value, ERC20 _tokenContract,
      uint _roomSlot) external {

        // Check if right token
        require(_tokenContract == ERC20(tracker_0x_address));

        // Adjust balance
        balance += _value;

        // transfers the token to the smart contract
        inputBid(_sender, _roomSlot, _value);
        require(ERC20(tracker_0x_address).transferFrom(_sender, address(this), _value));
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

                // Transfer biddings to the admin and transfer difference between highest
                // and second highest back to winner
                ERC20(tracker_0x_address).transfer(msg.sender,
                  RoomToBiddingMap[rooms[j]].highestBid);
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

    function timeValue() public view returns (uint) {
      return (time);
    }

    function flush() public isAdmin() isntRunning() {
        uint oldBalance = balance;
        balance = 0;
        ERC20(tracker_0x_address).transfer(msg.sender, oldBalance);
    }
}
