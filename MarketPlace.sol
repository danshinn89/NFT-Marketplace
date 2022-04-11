// SPDX-License-Identifier: UNLICENSED

// NFT Marketplace using ERC1155 token
// Once token(s) are minted create course they are transferred to the contract and added to the Marketplace
// Owner approves admins and cannot mint tokens
// Admin can mint, addresses to whitelist to bypass price on purchase
// Admin receive royalities for each time the NFT is resold
// Only users that have signed in can purchase NFT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketPlace is ERC1155, ERC2981, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    //EVENTS//
    event NewItemCreated(
        uint256 indexed id,
        address creator,
        address owner,
        uint256 price,
        uint256 _amount
    );

    struct NFT {
        uint256 id;
        address payable creator;
        //address payable owner;
        uint256 price;
        uint256 amount;
        string name;
        string company;
    }

    
    mapping(uint256 => NFT) public idToNFT;
    mapping(address => uint256) public users;
    mapping(uint256 => bool) private courseIds;
    mapping(uint256 => bool) private soldOut;
    mapping(address => bool) public admin;
    mapping(address => bool) public apprvUser;
    mapping(address => bool) public whitelist;

    uint256 public nextNFTId;
    uint256 public nextAdminId;
    uint256 public nextUserId;

    constructor() ERC1155("ipfs://example/{id}.json") {
        // set royalty of all NFTs to 5%
        _setDefaultRoyalty(_msgSender(), 500);
    }

    //OWNER ONLY//
    function approveAdmin(address _admin) public onlyOwner {
        require(admin[_admin] != true, "Already Admin");
        admin[_admin] = true;
        nextAdminId++;
    }

    //ADMINS ONLY//
    function createCourse(
        uint256 _id,
        uint256 _amount,
        uint256 _price,
        string memory _name,
        string memory _company
    ) public payable virtual onlyAdmin returns (uint256) {
        require(_price > 0, "Must be at least 1 Wei");
        _setDefaultRoyalty(_msgSender(), 500);
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, _id, _amount, "");

        createCourseItem(_id, _price, _amount, _name, _company);
        return newTokenId;
    }

    function createCourseItem(
        uint256 _id,
        uint256 _amount,
        uint256 _price,
        string memory _name,
        string memory _company
    ) private onlyAdmin {
        require(courseIds[_id] == false, "This ID is already taken");
        require(_price > 0, "Price must be at least 1 wei");

        idToNFT[_id] = NFT(
            _id,
            payable(msg.sender),
            //payable(address(this)),
            _amount,
            _price,
            _name,
            _company
        );

        _safeTransferFrom(msg.sender, address(this), _id, _amount, "");

        emit NewItemCreated(_id, msg.sender, address(this), _price, _amount);

        nextNFTId++;
    }

    function setUser(address _user) public {
        require(
            admin[_user] != true,
            "Already an admin. This address cannot be student"
        );
        apprvUser[_user] = true;
        nextUserId++;
    }
    
    //add addresses to whitelist
    function setWhiteList(address _whiteList) public onlyAdmin {
        whitelist[_whiteList] = true;
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(uint256 _id, uint256 _amount)
        public
        payable
        onlyUser
    {
        uint256 price = idToNFT[_id].price;
        uint256 tokenId = idToNFT[_id].id;
        require(idToNFT[_id].amount >= 1, "Course Sold Out");
        require(_amount == 1, "Amount too high, Select 1");
        if (whitelist[_msgSender()] == true) {
            _safeTransferFrom(address(this), msg.sender, tokenId, _amount, "");
            idToNFT[_id].amount = idToNFT[_id].amount - 1;
            if(idToNFT[_id].amount == 0) {
                soldOut[_id] = true;
            }
        } else {
            require(msg.value == price, "Please submit the asking price");
            idToNFT[_id].creator.transfer(msg.value);
            _safeTransferFrom(address(this), msg.sender, tokenId, _amount, "");
            idToNFT[_id].amount = idToNFT[_id].amount - 1;
            if(idToNFT[_id].amount == 0) {
                soldOut[_id] = true;
            }
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

   
    //MODIFIERS//
    //OnlyAdmins can use functions that utilize this modifier
    modifier onlyAdmin() {
        require(admin[_msgSender()] == true, "Only Admin");
        _;
    }

    
    modifier onlyUser() {
        require(
            apprvUser[_msgSender()] == true,
            "Please register as a Student"
        );
        _;
    }
}
