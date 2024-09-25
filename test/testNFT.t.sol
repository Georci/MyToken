pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ImageToken.sol";
import "../src/interface/IERC721A.sol";
import "../src/interface/IERC721Error.sol";

// interface IERC165 {
//     function supportsInterface(bytes4 interfaceId) external view returns (bool);
// }

contract testNFT is Test {
    address owner = vm.addr(1);
    address to = vm.addr(2);
    MyToken mytoken = new MyToken("Wukong", "Wkon", owner);
    string[] uris;
    uint256[] batchBurnArray;
    uint256[] batchTransferArray;

    function setUp() public {
        vm.startPrank(owner);
        uris.push(
            "https://ipfs.io/ipfs/QmRackxfCSTUg1GBSFGy6xMhFzNcfnR5vJDY8HSmaySNXF"
        );
        uris.push(
            "https://ipfs.io/ipfs/QmRPW6jY7tzgbsfAWXbymw4Cah9q7YeKUaquJAZpiGkbjZ"
        );
        //=========================  test mint ============================//
        mytoken.safeMint(to, 2, uris);

        uint256 nextMintTokenId = mytoken.totalSupply();
        console.log("now totalSupply is :", nextMintTokenId);
    }

    function testTokenURI() public {
        string memory a = mytoken.tokenURI(0);
        emit log_named_string("URI is :", a);

        string memory b = mytoken.tokenURI(1);
        emit log_named_string("URI is :", b);
    }

    function testBurn() public {
        vm.startPrank(owner);
        mytoken.burn(0);

        uint256 nextMintTokenId = mytoken.totalSupply();
        console.log("now totalSupply is :", nextMintTokenId);

        // 要保证burn之后，token uri消失
        string memory a = mytoken.tokenURI(0);
        emit log_named_string("URI is", a);

        string memory b = mytoken.tokenURI(1);
        emit log_named_string("URI is", b);
    }

    function testBatchBurn() public {
        vm.startPrank(to);
        batchBurnArray.push(0);
        batchBurnArray.push(1);

        uint256 totalSupply1 = mytoken.totalSupply();
        console.log("now totalSupply is :", totalSupply1);

        mytoken.batchBurn(batchBurnArray);

        uint256 totalSupply2 = mytoken.totalSupply();
        console.log("now totalSupply is :", totalSupply2);
    }

    function testTransferFrom() public {
        vm.startPrank(to);
        mytoken.transferFrom(to, owner, 1);

        console.log(to);
        console.log("0 token's owner is :", mytoken.ownerOf(0));

        console.log(owner);
        console.log("1 token's owner is :", mytoken.ownerOf(1));
    }

    // TODO:
    // 2.还有几个点需要验证，例如对于两个id不连续的token是否能否batchBurn、tranfer

    function testBatchTransferFrom() public {
        vm.startPrank(to);

        batchTransferArray.push(0);
        batchTransferArray.push(1);

        mytoken.batchTransferFrom(to, owner, batchTransferArray);

        console.log(to);
        console.log("0 token's owner is :", mytoken.ownerOf(0));

        console.log(owner);
        console.log("1 token's owner is :", mytoken.ownerOf(1));
    }

    function testSafeBatchTransferFrom() public {
        vm.startPrank(to);
        batchTransferArray.push(0);
        batchTransferArray.push(1);

        mytoken.safeBatchTransferFrom(
            address(0),
            to,
            owner,
            batchTransferArray,
            ""
        );

        console.log(to);
        console.log("0 token's owner is :", mytoken.ownerOf(0));

        console.log(owner);
        console.log("1 token's owner is :", mytoken.ownerOf(1));
    }

    function testBacthBurnNoSequentialToken() public {
        string[] memory ownerURIs = new string[](1);
        ownerURIs[0] = "2";
        mytoken.safeMint(owner, 1, ownerURIs);

        string[] memory toURIs = new string[](1);
        toURIs[0] = "3";
        mytoken.safeMint(to, 1, toURIs);

        console.log(owner);
        console.log("2 token's owner is :", mytoken.ownerOf(2));

        console.log(to);
        console.log("3 token's owner is :", mytoken.ownerOf(3));

        vm.startPrank(to);
        batchBurnArray.push(0);
        batchBurnArray.push(1);
        batchBurnArray.push(3);

        mytoken.batchBurn(batchBurnArray);
        console.log("now totalSupply is :", mytoken.totalSupply());

        string memory b = mytoken.tokenURI(3);
        emit log_named_string("URI is :", b);
    }

    function testInterfaceId() public {
        bool isEnoungth = IERC165(address(mytoken)).supportsInterface(
            0x11111111
        );

        console.log("isEnoungth is :{}", isEnoungth);
    }

    function test_getInterfaceId() public {
        bytes4 IERC721AinterfaceId = type(IERC721A).interfaceId;
        emit log_named_bytes32(
            "IERC721A interfaceId is :",
            IERC721AinterfaceId
        );

        bytes4 IERC721ERRorinterfaceId = type(IERC721Error).interfaceId;
        emit log_named_bytes32(
            "IERC721Error interfaceId is :",
            IERC721ERRorinterfaceId
        );
    }
}
