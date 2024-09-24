pragma solidity ^0.8.0;

import "./interface/IERC721A.sol";

/**
 * @dev Interface of ERC721 token receiver.
 */
interface ERC721A__IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract ERC721A is IERC721A {
    struct TokenApprovalRef {
        address value;
    }

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // The next token ID to be minted.
    uint256 internal _currentIndex;

    // The number of tokens burned.
    uint256 private _burnCounter;

    // Ken：以下这四个掩码用于在TokenOwnership中获取对应的数据
    // Mask of an entry in packed address data.
    uint256 private constant _BITMASK_ADDRESS_DATA_ENTRY = (1 << 64) - 1;

    // The bit position of `numberMinted` in packed address data.
    uint256 private constant _BITPOS_NUMBER_MINTED = 64;

    // The bit position of `numberBurned` in packed address data.
    uint256 private constant _BITPOS_NUMBER_BURNED = 128;

    // The bit position of `aux` in packed address data.
    uint256 private constant _BITPOS_AUX = 192;

    // The mask of the lower 160 bits for addresses.
    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    // The bit mask of the `burned` bit in packed ownership.
    uint256 private constant _BITMASK_BURNED = 1 << 224;

    // The bit position of `startTimestamp` in packed ownership.
    uint256 private constant _BITPOS_START_TIMESTAMP = 160;

    // The bit position of the `nextInitialized` bit in packed ownership.
    uint256 private constant _BITPOS_NEXT_INITIALIZED = 225;

    // The bit mask of the `nextInitialized` bit in packed ownership.
    uint256 private constant _BITMASK_NEXT_INITIALIZED = 1 << 225;

    // The bit position of `extraData` in packed ownership.
    uint256 private constant _BITPOS_EXTRA_DATA = 232;

    // Mask of all 256 bits in a packed ownership except the 24 bits for `extraData`.
    uint256 private constant _BITMASK_EXTRA_DATA_COMPLEMENT = (1 << 232) - 1;

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned.
    // See {_packedOwnershipOf} implementation for details.
    //
    // Bits Layout:
    // - [0..159]   `addr` 160bit
    // - [160..223] `startTimestamp` 64bit uint8
    // - [224]      `burned` bool
    // - [225]      `nextInitialized` bool 指示下一个tokenId是否已经被初始化
    // - [232..255] `extraData`
    mapping(uint256 => uint256) private _packedOwnerships;

    // Mapping owner address to address data.
    //
    // Bits Layout:
    // - [0..63]    `balance`
    // - [64..127]  `numberMinted`
    // - [128..191] `numberBurned`
    // - [192..255] `aux`
    mapping(address => uint256) private _packedAddressData;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Mapping from token ID to approved address.
    mapping(uint256 => TokenApprovalRef) private _tokenApprovals;

    // The `Transfer` event signature is given by:
    // `keccak256(bytes("Transfer(address,address,uint256)"))`.
    bytes32 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentIndex = _startTokenId();
    }

    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev 返回当前NFT的symbol
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev 返回第一个NFT的id
     */
    function _startTokenId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev 返回下一个可以被mint的NFT id
     */
    function _nextTokenId() internal view virtual returns (uint256) {
        return _currentIndex;
    }

    /**
     * @dev 返回可以连续铸造的最大的NFT id
     */
    function _sequentialUpTo() internal view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @dev 返回现存的NFT总数
     */
    function totalSupply()
        public
        view
        virtual
        override
        returns (uint256 result)
    {
        unchecked {
            result = _currentIndex - _burnCounter - _startTokenId();
        }
    }

    /**
     * @dev 返回当前合约铸造的NFT总数
     */
    function _totalMinted() internal view virtual returns (uint256 result) {
        unchecked {
            result = _currentIndex - _startTokenId();
        }
    }

    /**
     * @dev 返回当前合约销毁的NFT总数
     */
    function _totalBurned() internal view virtual returns (uint256) {
        return _burnCounter;
    }

    /**
     * @dev 返回一个账户目前所拥有的NFT数量
     * @param owner 账户
     */
    function balanceOf(
        address owner
    ) public view virtual override returns (uint256) {
        if (owner == address(0)) _revert(BalanceQueryForZeroAddress.selector);
        return _packedAddressData[owner] & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * @dev 返回指定id token的拥有者
     */
    function ownerOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        return address(uint160(_packedOwnershipOf(tokenId)));
    }

    // =============================================================
    //                        OWNERSHIP OPERATIONS
    // =============================================================

    /**
     * @dev Ken：将OwnershipData打包为一个uint256类型的数据
     */
    function _packOwnershipData(
        address owner,
        uint256 flags
    ) private view returns (uint256 result) {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // `owner | (block.timestamp << _BITPOS_START_TIMESTAMP) | flags`.
            result := or(
                owner,
                or(shl(_BITPOS_START_TIMESTAMP, timestamp()), flags)
            )
        }
    }

    /**
     * @dev Returns the `nextInitialized` flag set if `quantity` equals 1.
     */
    function _nextInitializedFlag(
        uint256 quantity
    ) private pure returns (uint256 result) {
        // For branchless setting of the `nextInitialized` flag.
        assembly {
            // `(quantity == 1) << _BITPOS_NEXT_INITIALIZED`.
            result := shl(_BITPOS_NEXT_INITIALIZED, eq(quantity, 1))
        }
    }

    // =============================================================
    //                        MINT OPERATIONS
    // =============================================================

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _mint(address to, uint256 quantity) internal virtual {
        uint256 startTokenId = _currentIndex;
        if (quantity == uint256(0)) _revert(MintZeroQuantity.selector);

        unchecked {
            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `quantity == 1`.
            _packedOwnerships[startTokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(quantity) |
                    _nextExtraData(address(0), to, 0)
            );

            // Updates:
            // - `balance += quantity`.
            // - `numberMinted += quantity`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            _packedAddressData[to] +=
                quantity *
                ((1 << _BITPOS_NUMBER_MINTED) | 1);

            // Mask to the lower 160 bits, in case the upper bits somehow aren't clean.
            // Zero address check
            uint256 toMasked = uint160(to);
            if (toMasked == uint256(0)) _revert(MintToZeroAddress.selector);

            uint256 end = startTokenId + quantity;
            uint256 tokenId = startTokenId;

            // Max limit check
            if (end - 1 > _sequentialUpTo())
                _revert(SequentialMintExceedsLimit.selector);

            do {
                assembly {
                    // Emit the `Transfer` event.
                    log4(
                        0, // Start of data (0, since no data).
                        0, // End of data (0, since no data).
                        _TRANSFER_EVENT_SIGNATURE, // Signature.
                        0, // `address(0)`.
                        toMasked, // `to`.
                        tokenId // `tokenId`.
                    )
                }
                // The `!=` check ensures that large values of `quantity`
                // that overflows uint256 will make the loop run out of gas.
            } while (++tokenId != end);

            _currentIndex = end;
        }
    }

    /**
     * @dev Safely mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `quantity` must be greater than 0.
     *
     * See {_mint}.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal virtual {
        _mint(to, quantity);

        unchecked {
            if (to.code.length != 0) {
                uint256 end = _currentIndex;
                uint256 index = end - quantity;
                do {
                    if (
                        !_checkContractOnERC721Received(
                            address(0),
                            to,
                            index++,
                            _data
                        )
                    ) {
                        _revert(
                            TransferToNonERC721ReceiverImplementer.selector
                        );
                    }
                } while (index < end);
                // This prevents reentrancy to `_safeMint`.
                // It does not prevent reentrancy to `_safeMintSpot`.
                if (_currentIndex != end) revert();
            }
        }
    }

    /**
     * @dev Equivalent to `_safeMint(to, quantity, '')`.
     */
    function _safeMint(address to, uint256 quantity) internal virtual {
        _safeMint(to, quantity, "");
    }

    // =============================================================
    //                        BURN OPERATIONS
    // =============================================================

    /**
     * @dev Equivalent to `_burn(tokenId, false)` 提供一个简单的接口
     */
    function _burn(uint256 tokenId) internal virtual {
        _burn(tokenId, false);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId, bool approvalCheck) internal virtual {
        // Ken：检查是否存在销毁权限
        uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);

        uint256 fromMasked = uint160(prevOwnershipPacked);
        address from = address(uint160(fromMasked));

        (
            uint256 approvedAddressSlot,
            uint256 approvedAddressValue
        ) = _getApprovedSlotAndValue(tokenId);

        if (approvalCheck) {
            // The nested ifs save around 20+ gas over a compound boolean condition.
            if (
                !_isSenderApprovedOrOwner(
                    approvedAddressValue,
                    fromMasked,
                    uint160(_msgSenderERC721A())
                )
            )
                if (!isApprovedForAll(from, _msgSenderERC721A()))
                    _revert(TransferCallerNotOwnerNorApproved.selector);
        }

        assembly {
            if approvedAddressValue {
                sstore(approvedAddressSlot, 0) // Equivalent to `delete _tokenApprovals[tokenId]`.
            }
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as `tokenId` would have to be 2**256.
        // Ken：这样的unchecked的操作都是为了节省gas
        unchecked {
            // Updates:
            // - `balance -= 1`.
            // - `numberBurned += 1`.
            //
            // We can directly decrement the balance, and increment the number burned.
            // This is equivalent to `packed -= 1; packed += 1 << _BITPOS_NUMBER_BURNED;`.
            _packedAddressData[from] += (1 << _BITPOS_NUMBER_BURNED) - 1;

            // Updates:
            // - `address` to the last owner.
            // - `startTimestamp` to the timestamp of burning.
            // - `burned` to `true`.
            // - `nextInitialized` to `true`.
            _packedOwnerships[tokenId] = _packOwnershipData(
                from,
                (_BITMASK_BURNED | _BITMASK_NEXT_INITIALIZED) |
                    _nextExtraData(from, address(0), prevOwnershipPacked)
            );

            // If the next slot may not have been initialized (i.e. `nextInitialized == false`) .
            if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == uint256(0)) {
                uint256 nextTokenId = tokenId + 1;
                // If the next slot's address is zero and not burned (i.e. packed value is zero).
                if (_packedOwnerships[nextTokenId] == uint256(0)) {
                    // If the next slot is within bounds.
                    if (nextTokenId != _currentIndex) {
                        // Initialize the next slot to maintain correctness for `ownerOf(tokenId + 1)`.
                        _packedOwnerships[nextTokenId] = prevOwnershipPacked;
                    }
                }
            }
        }

        emit Transfer(from, address(0), tokenId);

        // Overflow not possible, as `_burnCounter` cannot be exceed `_currentIndex + _spotMinted` times.
        unchecked {
            _burnCounter++;
        }
    }

    /**
     * @dev Destroys `tokenIds`.
     * Approvals are not cleared when tokenIds are burned.
     *
     * Requirements:
     *
     * - `tokenIds` must exist.
     * - `tokenIds` must be strictly ascending.
     * - `by` must be approved to burn these tokens by either {approve} or {setApprovalForAll}.
     *
     * `by` is the address that to check token approval for.
     * If token approval check is not needed, pass in `address(0)` for `by`.
     *
     * Emits a {Transfer} event for each token burned.
     */
    function _batchBurn(
        address by,
        uint256[] memory tokenIds
    ) internal virtual {
        // Early return if `tokenIds` is empty.
        if (tokenIds.length == uint256(0)) return;
        // The next `tokenId` to be minted (i.e. `_nextTokenId()`).
        uint256 end = _currentIndex;
        // Pointer to start and end (exclusive) of `tokenIds`.
        (uint256 ptr, uint256 ptrEnd) = _mdataERC721A(tokenIds);

        uint256 prevOwnershipPacked;
        address prevTokenOwner;
        uint256 prevTokenId;
        bool mayBurn;
        unchecked {
            do {
                uint256 tokenId = _mloadERC721A(ptr);
                uint256 miniBatchStart = tokenId;
                // Revert `tokenId` is out of bounds.
                if (_orERC721A(tokenId < _startTokenId(), end <= tokenId))
                    _revert(OwnerQueryForNonexistentToken.selector);
                // Revert if `tokenIds` is not strictly ascending.
                if (prevOwnershipPacked != 0)
                    if (tokenId <= prevTokenId)
                        _revert(TokenIdsNotStrictlyAscending.selector);
                // Scan backwards for an initialized packed ownership slot.
                // ERC721A's invariant guarantees that there will always be an initialized slot as long as
                // the start of the backwards scan falls within `[_startTokenId() .. _nextTokenId())`.
                for (
                    uint256 j = tokenId;
                    (prevOwnershipPacked = _packedOwnerships[j]) == uint256(0);

                ) --j;
                // If the initialized slot is burned, revert.
                if (prevOwnershipPacked & _BITMASK_BURNED != 0)
                    _revert(OwnerQueryForNonexistentToken.selector);

                address tokenOwner = address(uint160(prevOwnershipPacked));
                if (tokenOwner != prevTokenOwner) {
                    prevTokenOwner = tokenOwner;
                    mayBurn =
                        _orERC721A(by == address(0), tokenOwner == by) ||
                        isApprovedForAll(tokenOwner, by);
                }

                do {
                    (
                        uint256 approvedAddressSlot,
                        uint256 approvedAddressValue
                    ) = _getApprovedSlotAndValue(tokenId);
                    // Revert if the sender is not authorized to transfer the token.
                    if (!mayBurn)
                        if (uint160(by) != approvedAddressValue)
                            _revert(TransferCallerNotOwnerNorApproved.selector);
                    assembly {
                        if approvedAddressValue {
                            sstore(approvedAddressSlot, 0) // Equivalent to `delete _tokenApprovals[tokenId]`.
                        }
                        // Emit the `Transfer` event.
                        log4(
                            0,
                            0,
                            _TRANSFER_EVENT_SIGNATURE,
                            and(_BITMASK_ADDRESS, tokenOwner),
                            0,
                            tokenId
                        )
                    }
                    if (_mloadERC721A(ptr += 0x20) != ++tokenId) break;
                    if (ptr == ptrEnd) break;
                } while (_packedOwnerships[tokenId] == uint256(0));

                // Updates tokenId:
                // - `address` to the same `tokenOwner`.
                // - `startTimestamp` to the timestamp of transferring.
                // - `burned` to `true`.
                // - `nextInitialized` to `false`, as it is optional.
                _packedOwnerships[miniBatchStart] = _packOwnershipData(
                    tokenOwner,
                    _BITMASK_BURNED |
                        _nextExtraData(
                            tokenOwner,
                            address(0),
                            prevOwnershipPacked
                        )
                );
                uint256 miniBatchLength = tokenId - miniBatchStart;
                // Update the address data.
                _packedAddressData[tokenOwner] +=
                    (miniBatchLength << _BITPOS_NUMBER_BURNED) -
                    miniBatchLength;
                // Initialize the next slot if needed.
                if (tokenId != end)
                    if (_packedOwnerships[tokenId] == uint256(0))
                        _packedOwnerships[tokenId] = prevOwnershipPacked;
                // Set the `prevTokenId` for checking that the `tokenIds` is strictly ascending.
                prevTokenId = tokenId - 1;
            } while (ptr != ptrEnd);
            // Increment the overall burn counter.
            _burnCounter += tokenIds.length;
        }
    }

    // =============================================================
    //                        TRANSFER OPERATIONS
    // =============================================================

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public payable virtual override {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0)
            if (!_checkContractOnERC721Received(from, to, tokenId, _data)) {
                _revert(TransferToNonERC721ReceiverImplementer.selector);
            }
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override {
        uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);
        uint256 fromMasked = uint160(from);

        if (uint160(prevOwnershipPacked) != fromMasked)
            _revert(TransferFromIncorrectOwner.selector);
        // 从对应的插槽中获取该NFT id对应的slot key 和 slot value(owner address)
        (
            uint256 approvedAddressSlot,
            uint256 approvedAddressValue
        ) = _getApprovedSlotAndValue(tokenId);

        // The nested ifs save around 20+ gas over a compound boolean condition.
        if (
            !_isSenderApprovedOrOwner(
                approvedAddressValue,
                fromMasked,
                uint160(_msgSenderERC721A())
            )
        )
            if (!isApprovedForAll(from, _msgSenderERC721A()))
                _revert(TransferCallerNotOwnerNorApproved.selector);

        assembly {
            if approvedAddressValue {
                sstore(approvedAddressSlot, 0) // Equivalent to `delete _tokenApprovals[tokenId]`.
            }
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as `tokenId` would have to be 2**256.
        unchecked {
            // We can directly increment and decrement the balances.
            --_packedAddressData[from]; // Updates: `balance -= 1`.
            ++_packedAddressData[to]; // Updates: `balance += 1`.

            // Updates:
            // - `address` to the next owner.
            // - `startTimestamp` to the timestamp of transfering.
            // - `burned` to `false`.
            // - `nextInitialized` to `true`.
            _packedOwnerships[tokenId] = _packOwnershipData(
                to,
                _BITMASK_NEXT_INITIALIZED |
                    _nextExtraData(from, to, prevOwnershipPacked)
            );

            // If the next slot may not have been initialized (i.e. `nextInitialized == false`) .
            if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == uint256(0)) {
                uint256 nextTokenId = tokenId + 1;
                // If the next slot's address is zero and not burned (i.e. packed value is zero).
                if (_packedOwnerships[nextTokenId] == uint256(0)) {
                    // If the next slot is within bounds.
                    if (nextTokenId != _currentIndex) {
                        // Initialize the next slot to maintain correctness for `ownerOf(tokenId + 1)`.
                        _packedOwnerships[nextTokenId] = prevOwnershipPacked;
                    }
                }
            }
        }

        // Mask to the lower 160 bits, in case the upper bits somehow aren't clean.
        uint256 toMasked = uint160(to);
        assembly {
            // Emit the `Transfer` event.
            log4(
                0, // Start of data (0, since no data).
                0, // End of data (0, since no data).
                _TRANSFER_EVENT_SIGNATURE, // Signature.
                fromMasked, // `from`.
                toMasked, // `to`.
                tokenId // `tokenId`.
            )
        }
        if (toMasked == uint256(0)) _revert(TransferToZeroAddress.selector);
    }

    /**
     * @dev Equivalent to `_batchTransferFrom(from, to, tokenIds)`.
     */
    function _batchTransferFrom(
        address from,
        address to,
        uint256[] memory tokenIds
    ) internal virtual {
        _batchTransferFrom(address(0), from, to, tokenIds);
    }

    /**
     * @dev Transfers `tokenIds` in batch from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenIds` tokens must be owned by `from`.
     * - `tokenIds` must be strictly ascending.
     * - If `by` is not `from`, it must be approved to move these tokens
     * by either {approve} or {setApprovalForAll}.
     *
     * `by` is the address that to check token approval for.
     * If token approval check is not needed, pass in `address(0)` for `by`.
     *
     * Emits a {Transfer} event for each transfer.
     */
    function _batchTransferFrom(
        address by,
        address from,
        address to,
        uint256[] memory tokenIds
    ) internal virtual {
        uint256 byMasked = uint160(by);
        uint256 fromMasked = uint160(from);
        uint256 toMasked = uint160(to);
        // Disallow transfer to zero address.
        if (toMasked == uint256(0)) _revert(TransferToZeroAddress.selector);
        // Whether `by` may transfer the tokens.
        bool mayTransfer = _orERC721A(
            byMasked == uint256(0),
            byMasked == fromMasked
        ) || isApprovedForAll(from, by);

        // Early return if `tokenIds` is empty.
        if (tokenIds.length == uint256(0)) return;
        // The next `tokenId` to be minted (i.e. `_nextTokenId()`).
        uint256 end = _currentIndex;
        // Pointer to start and end (exclusive) of `tokenIds`.
        (uint256 ptr, uint256 ptrEnd) = _mdataERC721A(tokenIds);

        uint256 prevTokenId;
        uint256 prevOwnershipPacked;
        unchecked {
            do {
                uint256 tokenId = _mloadERC721A(ptr);
                uint256 miniBatchStart = tokenId;
                // Revert `tokenId` is out of bounds.
                if (_orERC721A(tokenId < _startTokenId(), end <= tokenId))
                    _revert(OwnerQueryForNonexistentToken.selector);
                // Revert if `tokenIds` is not strictly ascending.
                if (prevOwnershipPacked != 0)
                    if (tokenId <= prevTokenId)
                        _revert(TokenIdsNotStrictlyAscending.selector);
                // Scan backwards for an initialized packed ownership slot.
                // ERC721A's invariant guarantees that there will always be an initialized slot as long as
                // the start of the backwards scan falls within `[_startTokenId() .. _nextTokenId())`.
                for (
                    uint256 j = tokenId;
                    (prevOwnershipPacked = _packedOwnerships[j]) == uint256(0);

                ) --j;
                // If the initialized slot is burned, revert.
                if (prevOwnershipPacked & _BITMASK_BURNED != 0)
                    _revert(OwnerQueryForNonexistentToken.selector);
                // Check that `tokenId` is owned by `from`.
                if (uint160(prevOwnershipPacked) != fromMasked)
                    _revert(TransferFromIncorrectOwner.selector);

                do {
                    (
                        uint256 approvedAddressSlot,
                        uint256 approvedAddressValue
                    ) = _getApprovedSlotAndValue(tokenId);
                    // Revert if the sender is not authorized to transfer the token.
                    if (!mayTransfer)
                        if (byMasked != approvedAddressValue)
                            _revert(TransferCallerNotOwnerNorApproved.selector);
                    assembly {
                        if approvedAddressValue {
                            sstore(approvedAddressSlot, 0) // Equivalent to `delete _tokenApprovals[tokenId]`.
                        }
                        // Emit the `Transfer` event.
                        log4(
                            0,
                            0,
                            _TRANSFER_EVENT_SIGNATURE,
                            fromMasked,
                            toMasked,
                            tokenId
                        )
                    }

                    if (_mloadERC721A(ptr += 0x20) != ++tokenId) break;
                    if (ptr == ptrEnd) break;
                } while (_packedOwnerships[tokenId] == uint256(0));

                // Updates tokenId:
                // - `address` to the next owner.
                // - `startTimestamp` to the timestamp of transferring.
                // - `burned` to `false`.
                // - `nextInitialized` to `false`, as it is optional.
                _packedOwnerships[miniBatchStart] = _packOwnershipData(
                    address(uint160(toMasked)),
                    _nextExtraData(
                        address(uint160(fromMasked)),
                        address(uint160(toMasked)),
                        prevOwnershipPacked
                    )
                );
                uint256 miniBatchLength = tokenId - miniBatchStart;
                // Update the address data.
                _packedAddressData[
                    address(uint160(fromMasked))
                ] -= miniBatchLength;
                _packedAddressData[
                    address(uint160(toMasked))
                ] += miniBatchLength;
                // Initialize the next slot if needed.
                if (tokenId != end)
                    if (_packedOwnerships[tokenId] == uint256(0))
                        _packedOwnerships[tokenId] = prevOwnershipPacked;
                // Perform the after hook for the batch.

                prevTokenId = tokenId - 1;
            } while (ptr != ptrEnd);
        }
    }

    /**
     * @dev Safely transfers `tokenIds` in batch from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenIds` tokens must be owned by `from`.
     * - If `by` is not `from`, it must be approved to move these tokens
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called for each transferred token.
     *
     * `by` is the address that to check token approval for.
     * If token approval check is not needed, pass in `address(0)` for `by`.
     *
     * Emits a {Transfer} event for each transfer.
     */
    function _safeBatchTransferFrom(
        address by,
        address from,
        address to,
        uint256[] memory tokenIds,
        bytes memory _data
    ) internal virtual {
        _batchTransferFrom(by, from, to, tokenIds);

        unchecked {
            if (to.code.length != 0) {
                for (
                    (uint256 ptr, uint256 ptrEnd) = _mdataERC721A(tokenIds);
                    ptr != ptrEnd;
                    ptr += 0x20
                ) {
                    if (
                        !_checkContractOnERC721Received(
                            from,
                            to,
                            _mloadERC721A(ptr),
                            _data
                        )
                    ) {
                        _revert(
                            TransferToNonERC721ReceiverImplementer.selector
                        );
                    }
                }
            }
        }
    }

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target contract.
     *
     * `from` - Previous owner of the given token ID.
     * `to` - Target address that will receive the token.
     * `tokenId` - Token ID to be transferred.
     * `_data` - Optional data to send along with the call.
     *
     * Returns whether the call correctly returned the expected magic value.
     */
    function _checkContractOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        // 所以只要是将NFT转账到某个合约是不是都会有一次回调该合约中onERC721Received函数的机会
        // _data就是在执行该函数是传入的参数
        try
            ERC721A__IERC721Receiver(to).onERC721Received(
                _msgSenderERC721A(),
                from,
                tokenId,
                _data
            )
        returns (bytes4 retval) {
            return
                retval ==
                ERC721A__IERC721Receiver(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == uint256(0)) {
                _revert(TransferToNonERC721ReceiverImplementer.selector);
            }
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }
    }

    /**
     * @dev 返回当前调用者是否是被approved的地址或者是owner地址
     */
    function _isSenderApprovedOrOwner(
        uint256 approvedAddressValue,
        uint256 ownerMasked,
        uint256 msgSenderMasked
    ) internal pure returns (bool result) {
        assembly {
            result := or(
                eq(msgSenderMasked, ownerMasked),
                eq(msgSenderMasked, approvedAddressValue)
            )
        }
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        _operatorApprovals[_msgSenderERC721A()][operator] = approved;
        emit ApprovalForAll(_msgSenderERC721A(), operator, approved);
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted. See {_mint}.
     */
    function _exists(
        uint256 tokenId
    ) internal view virtual returns (bool result) {
        if (_startTokenId() <= tokenId) {
            if (tokenId > _sequentialUpTo())
                return _packedOwnershipExists(_packedOwnerships[tokenId]);

            if (tokenId < _currentIndex) {
                uint256 packed;
                while ((packed = _packedOwnerships[tokenId]) == uint256(0))
                    --tokenId;
                result = packed & _BITMASK_BURNED == uint256(0);
            }
        }
    }

    /**
     * @dev Returns the storage slot and value for the approved address of `tokenId` casted to a uint256.
     */
    function _getApprovedSlotAndValue(
        uint256 tokenId
    )
        internal
        view
        returns (uint256 approvedAddressSlot, uint256 approvedAddressValue)
    {
        TokenApprovalRef storage tokenApproval = _tokenApprovals[tokenId];
        // The following is equivalent to `approvedAddressValue = uint160(_tokenApprovals[tokenId].value)`.
        assembly {
            approvedAddressSlot := tokenApproval.slot
            approvedAddressValue := sload(approvedAddressSlot)
        }
    }

    // =============================================================
    //                       APPROVAL OPERATIONS
    // =============================================================

    /**
     * @dev Equivalent to `_approve(to, tokenId, false)`.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _approve(to, tokenId, false);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function _approve(
        address to,
        uint256 tokenId,
        bool approvalCheck
    ) internal virtual {
        address owner = ownerOf(tokenId);

        if (approvalCheck && _msgSenderERC721A() != owner)
            if (!isApprovedForAll(owner, _msgSenderERC721A())) {
                _revert(ApprovalCallerNotOwnerNorApproved.selector);
            }

        _tokenApprovals[tokenId].value = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account. See {ERC721A-_approve}.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     */
    function approve(
        address to,
        uint256 tokenId
    ) public payable virtual override {
        _approve(to, tokenId, true);
    }

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(
        uint256 tokenId
    ) public view virtual override returns (address) {
        if (!_exists(tokenId))
            _revert(ApprovalQueryForNonexistentToken.selector);

        return _tokenApprovals[tokenId].value;
    }

    /**
     * 返回指定账户铸造的NFT数量
     */
    function _numberMinted(address owner) internal view returns (uint256) {
        return
            (_packedAddressData[owner] >> _BITPOS_NUMBER_MINTED) &
            _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * 返回由owner或者代表owner销毁的代币数量
     */
    function _numberBurned(address owner) internal view returns (uint256) {
        return
            (_packedAddressData[owner] >> _BITPOS_NUMBER_BURNED) &
            _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * @dev 根据token id查询用户信息
     */
    function _packedOwnershipOf(
        uint256 tokenId
    ) private view returns (uint256 packed) {
        if (_startTokenId() <= tokenId) {
            packed = _packedOwnerships[tokenId];

            if (tokenId > _sequentialUpTo()) {
                if (_packedOwnershipExists(packed)) return packed;
                _revert(OwnerQueryForNonexistentToken.selector);
            }

            // If the data at the starting slot does not exist, start the scan.
            if (packed == uint256(0)) {
                if (tokenId >= _currentIndex)
                    _revert(OwnerQueryForNonexistentToken.selector);
                // Invariant:
                // There will always be an initialized ownership slot
                // (i.e. `ownership.addr != address(0) && ownership.burned == false`)
                // before an unintialized ownership slot
                // (i.e. `ownership.addr == address(0) && ownership.burned == false`)
                // Hence, `tokenId` will not underflow.
                //
                // We can directly compare the packed value.
                // If the address is zero, packed will be zero.
                // Ken：递减操作，直至找到相应的owner
                for (;;) {
                    unchecked {
                        packed = _packedOwnerships[--tokenId];
                    }
                    if (packed == uint256(0)) continue;
                    if (packed & _BITMASK_BURNED == uint256(0)) return packed;
                    // Otherwise, the token is burned, and we must revert.
                    // This handles the case of batch burned tokens, where only the burned bit
                    // of the starting slot is set, and remaining slots are left uninitialized.
                    _revert(OwnerQueryForNonexistentToken.selector);
                }
            }
            // Otherwise, the data exists and we can skip the scan.
            // This is possible because we have already achieved the target condition.
            // This saves 2143 gas on transfers of initialized tokens.
            // If the token is not burned, return `packed`. Otherwise, revert.
            if (packed & _BITMASK_BURNED == uint256(0)) return packed;
        }
        _revert(OwnerQueryForNonexistentToken.selector);
    }

    /**
     * @dev 返回当前的packed是否表示一个NFT存在
     */
    function _packedOwnershipExists(
        uint256 packed
    ) private pure returns (bool result) {
        assembly {
            // The following is equivalent to `owner != address(0) && burned == false`.
            // 只有当owner不为0，且未被销毁时(一旦被销毁，owner变成0)，result才能为true
            result := gt(
                and(packed, _BITMASK_ADDRESS),
                and(packed, _BITMASK_BURNED)
            )
        }
    }

    // =============================================================
    //                     EXTRA DATA OPERATIONS
    // =============================================================

    /**
     * @dev Directly sets the extra data for the ownership data `index`.
     */
    function _setExtraDataAt(uint256 index, uint24 extraData) internal virtual {
        uint256 packed = _packedOwnerships[index];
        if (packed == uint256(0))
            _revert(OwnershipNotInitializedForExtraData.selector);
        uint256 extraDataCasted;
        // Cast `extraData` with assembly to avoid redundant masking.
        assembly {
            extraDataCasted := extraData
        }
        packed =
            (packed & _BITMASK_EXTRA_DATA_COMPLEMENT) |
            (extraDataCasted << _BITPOS_EXTRA_DATA);
        _packedOwnerships[index] = packed;
    }

    /**
     * @dev Called during each token transfer to set the 24bit `extraData` field.
     * Intended to be overridden by the cosumer contract.
     *
     * `previousExtraData` - the value of `extraData` before transfer.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _extraData(
        address from,
        address to,
        uint24 previousExtraData
    ) internal view virtual returns (uint24) {}

    /**
     * @dev Returns the next extra data for the packed ownership data.
     * The returned result is shifted into position.
     */
    function _nextExtraData(
        address from,
        address to,
        uint256 prevOwnershipPacked
    ) private view returns (uint256) {
        uint24 extraData = uint24(prevOwnershipPacked >> _BITPOS_EXTRA_DATA);
        return uint256(_extraData(from, to, extraData)) << _BITPOS_EXTRA_DATA;
    }

    /**
     * @dev 这个函数可以被用来检测某个合约是否实现了对应接口中的函数
     * @param interfaceId 传入的合约interfaceId,可以通过type(interface).interfaceId来获取
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 interface ID for ERC165.
            interfaceId == 0x80ac58cd || // ERC165 interface ID for ERC721.
            interfaceId == 0x5b5e139f || // ERC165 interface ID for ERC721Metadata.
            interfaceId == 0x18160ddd; // ERC165 interface ID for ERC721A
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _revert(URIQueryForNonexistentToken.selector);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length != 0
                ? string(abi.encodePacked(baseURI, _toString(tokenId)))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, it can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    // =============================================================
    //                        PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Returns a memory pointer to the start of `a`'s data.
     */
    function _mdataERC721A(
        uint256[] memory a
    ) private pure returns (uint256 start, uint256 end) {
        assembly {
            start := add(a, 0x20)
            end := add(start, shl(5, mload(a)))
        }
    }

    /**
     * @dev Returns the uint256 at `p` in memory.
     */
    function _mloadERC721A(uint256 p) private pure returns (uint256 result) {
        assembly {
            result := mload(p)
        }
    }

    /**
     * @dev Branchless boolean or.
     */
    function _orERC721A(bool a, bool b) private pure returns (bool result) {
        assembly {
            result := or(iszero(iszero(a)), iszero(iszero(b)))
        }
    }

    // =============================================================
    //                     UTILS OPERATION
    // =============================================================

    /**
     * @dev For more efficient reverts.
     */
    function _revert(bytes4 errorSelector) internal pure {
        assembly {
            mstore(0x00, errorSelector)
            revert(0x00, 0x04)
        }
    }

    /**
     * @dev Returns the message sender (defaults to `msg.sender`).
     *
     * If you are writing GSN compatible contracts, you need to override this function.
     */
    function _msgSenderERC721A() internal view virtual returns (address) {
        return msg.sender;
    }

    /**
     * @dev Converts a uint256 to its ASCII string decimal representation.
     */
    function _toString(
        uint256 value
    ) internal pure virtual returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }
}
