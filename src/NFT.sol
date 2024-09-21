pragma solidity ^0.8.0;

import "./ERC721AURIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFT MyToken项目入口
 * @author Ken
 * @notice 本项目基于ERC721A开发
 * @notice ERC721AURIStorage继承ERC721A，并且对URI数据进行管理
 * @notice Ownable对项目相关权限进行访问控制
 */
contract MyToken is ERC721A_URIStorage, Ownable {
    // Optional mapping for token URIs
    mapping(uint256 tokenId => string) private _tokenURIs;

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC721A(name, symbol) Ownable(initialOwner) {}

    /**
     * @dev Safely Mint 最外层函数，为to地址铸造quantity数量的token，同时为每个token分配一个unique URI。
     * @notice 该函数根据铸造的数量调用不同的URI分配函数
     *
     * Requirements:
     *
     * - `to` 不能为0地址，在父合约函数中进行检查
     * - `quantity` 铸造的数量要求大于0，在父合约函数中进行检查
     * - `uri` 要求铸造的数量与uri长度匹配
     */
    function safeMint(
        address to,
        uint256 quantity,
        string[] memory uri
    ) public onlyOwner {
        uint256 tokenId = _currentIndex;

        require(
            quantity == uri.length,
            "Quantity does not match the length of the URI array."
        );
        // 单个token mint
        if (quantity == 1) {
            _setTokenURI(tokenId, uri[0]);
        }
        // 多个token mint
        else if (quantity > 1) {
            _setBatchTokenURI(tokenId, uri);
        }
        _safeMint(to, quantity);
    }

    /**
     * @dev Safely 批量将 tokenIds 从from地址转移到to地址。
     * @param by 当前操作的operator
     * @param from 转账token的提供者
     * @param to 转账接收者地址
     * @param tokenIds 进行转账的NFT tokens
     * @param data 当 `to` 地址为合约地址时，data为进行回调时使用的参数
     * Requirements:
     * - 以下这些检查均在父合约的函数中完成：
     *
     * - `from` 不能为0地址，在父合约函数中进行检查
     * - `to` 不能为0地址，在父合约函数中进行检查
     * - `tokenIds` 必须归from所有
     * - 如果 `by` != `from`，则by需要被from授权
     * - 如果 `to` 地址是合约地址，则该合约必须实现了{IERC721Receiver-onERC721Received}
     *
     * 如果无需开启转账授权检查，则将by传入0地址
     */
    function safeBatchTransferFrom(
        address by,
        address from,
        address to,
        uint256[] memory tokenIds,
        bytes memory data
    ) public {
        _safeBatchTransferFrom(by, from, to, tokenIds, data);
    }

    /**
     * @dev 批量将 tokenIds 从from地址转移到to地址。
     * 相比于safeBatchTransferFrom函数缺少当前操作者进行检查的逻辑，及不允许非转账者本人调用该函数
     */
    function batchTransferFrom(
        address from,
        address to,
        uint256[] memory tokenIds
    ) public {
        _batchTransferFrom(from, to, tokenIds);
    }

    /**
     * @dev 销毁传入Id的NFT token，同时删除该token对应的URI
     * @param tokenId 要销毁的token Id
     * Requirements:
     * - 以下这些检查均在父合约的函数中完成：
     *
     * - `tokenId` 应当为已经铸造的NFT token id
     * - `msg.sender` 当前operator应当具有销毁权限
     */
    function burn(uint256 tokenId) public {
        _burn(tokenId);
        _deleteTokenURI(tokenId);
    }

    function batchBurn(uint256[] memory tokenIds) public {
        _batchBurn(_msgSenderERC721A(), tokenIds);
        _deleteBatchTokenURI(tokenIds);
    }

    //============================================================
    //=========Ken：以下这两个函数是被solidity强制要求重写===========
    //============================================================
    /**
     * @dev 返回指定token id对应的URI
     * Requirements:
     * - 以下这些检查均在父合约的函数中完成：
     *
     * - `tokenId` 应当为已经铸造的NFT token id
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev 检查输入的interface中函数是否在当前合约中全部实现
     * @param interfaceId 想要检查实现接口函数的interfaceId
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
