// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/ERC721URIStorage.sol)

pragma solidity ^0.8.0;

import {ERC721A} from "./ERC721A.sol";

/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721A_URIStorage is ERC721A {
    event MetadataUpdate(uint256 _tokenId);

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _exists(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via string.concat).
        if (bytes(_tokenURI).length > 0) {
            return string.concat(base, _tokenURI);
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Emits {MetadataUpdate}.
     */
    function _setTokenURI(
        uint256 tokenId,
        string memory _tokenURI
    ) internal virtual {
        _tokenURIs[tokenId] = _tokenURI;
        emit MetadataUpdate(tokenId);
    }

    /**
     * @dev Sets `_setBatchTokenURI` as the tokenURI of `tokenId`.
     *
     * Emits {MetadataUpdate}.
     */
    //TODO:释放大量事件
    function _setBatchTokenURI(
        uint256 tokenId,
        string[] memory _tokenURI
    ) internal virtual {
        uint256 length = _tokenURI.length;

        for (uint8 i = 0; i < length; i++) {
            _tokenURIs[tokenId + i] = _tokenURI[i];

            emit MetadataUpdate(tokenId);
        }
    }

    function _deleteTokenURI(uint256 tokenId) internal {
        // 在该函数被执行之前已经在_burn函数中执行了身份验证，故不再需要权限检查
        delete _tokenURIs[tokenId];
    }

    function _deleteBatchTokenURI(uint256[] memory tokenIds) public {
        for (uint8 i = 0; i < tokenIds.length; i++) {
            delete _tokenURIs[tokenIds[i]];
        }
    }
}
