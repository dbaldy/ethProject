pragma solidity ^0.4.15;

contract ERC20Interface {
  function transferFrom(address _from, address _to, uint _value) public returns (bool){}
}

//Ownable Contract makes the creator of the contract the owner
//it also allows the owner to transfer the ownership to a different address
contract Ownable {
  address public owner;

  function Ownable() public {
    owner = msg.sender;
  }

  modifier onlyOwner()  {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }
}

//the airdrop itself is a simple contract, which transfers tokens to several addresses through a for loop
contract TokenAirDrop is Ownable {

  function airDrop ( address contractObj,
                    address   tokenRepo,
                    address[] airDropDesinationAddress,
                    uint[] amounts) public onlyOwner{

    for( uint i = 0 ; i < airDropDesinationAddress.length ; i++ ) {

        ERC20Interface(contractObj).transferFrom( tokenRepo, airDropDesinationAddress[i],amounts[i]);
    }
   }
}
