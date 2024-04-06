// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Yul - language used for Solidity inline assembly
contract YulIntro {
    // Intro (list topics)
    // NOTE: Yul syntax

    // NOTE: Yul assignment
    function test_yul_var() public pure returns (uint256) {
        uint256 s = 0;

        assembly {
            // Declare variable
            let x := 1
            // Reassign
            x := 2
            // Assign to Solidity variable
            s := 2
        }

        return s;
    }

    // NOTE: Yul types (everything is bytes32)
    function test_yul_types() public pure returns (bool, uint256, bytes32) {
        bool x;
        uint256 y;
        bytes32 z;

        assembly {
            x := 1
            y := 0xaaa
            z := "Hello Yul"
        }

        return (x, y, z);
    }
}

contract EVMStorageSingleSlot {
    // NOTE:
    // 2**256 slots, each slot can store 32 bytes
    // Slots are assigned in the order they are declared
    // TODO: how is data packed for bytes?
    // Data < 32 bytes are packed into a slot (right to left?)
    // Struct
    // sstore, sload

    // Single variable stored in one slot
    // slot 0
    uint256 public s_x;
    // slot 1
    uint256 public s_y;
    // slot 2
    bytes32 public s_z;

    function test_sstore() public {
        assembly {
            sstore(0, 111)
            sstore(1, 222)
            sstore(2, 0xababab)
        }
    }

    function test_sstore_again() public {
        assembly {
            sstore(s_x.slot, 123)
            sstore(s_y.slot, 456)
            sstore(s_z.slot, 0xcdcdcd)
        }
    }

    function test_sload()
        public
        view
        returns (uint256 x, uint256 y, bytes32 z)
    {
        assembly {
            x := sload(0)
            y := sload(1)
            z := sload(2)
        }

        return (x, y, z);
    }

    function test_sload_again()
        public
        view
        returns (uint256 x, uint256 y, bytes32 z)
    {
        assembly {
            x := sload(s_x.slot)
            y := sload(s_y.slot)
            z := sload(s_z.slot)
        }

        return (x, y, z);
    }
}

contract BitMasking {
    function test_mask() public pure returns (bytes32 mask) {
        assembly {
            // |       256 bits        |
            // 000 ... 000 | 111 ... 111
            //             | 16 bits
            // 0x000000000000000000000000000000000000000000000000000000000000ffff
            mask := sub(shl(16, 1), 1)
        }
    }

    function test_shift_mask() public pure returns (bytes32 mask) {
        assembly {
            // |               256 bits                |
            // 000 ... 000 | 111 ... 111 | 000 ... 000 |
            //             | 16 bits     | 32 bits
            // 0x0000000000000000000000000000000000000000000000000000ffff00000000
            mask := shl(32, sub(shl(16, 1), 1))
        }
    }

    function test_not_mask() public pure returns (bytes32 mask) {
        assembly {
            // |               256 bits                |
            // 111 ... 111 | 000 ... 000 | 111 ... 111 |
            //             | 16 bits     | 32 bits
            // 0xffffffffffffffffffffffffffffffffffffffffffffffffffff0000ffffffff
            mask := not(shl(32, sub(shl(16, 1), 1)))
        }
    }
}

contract EVMStoragePackedSlot {
    // Data < 32 bytes are packed into a slot
    // Bit masking (how to create 111...111)
    // slot, offset

    // slot 0
    uint128 public s_a;
    uint64 public s_b;
    uint32 public s_c;
    uint32 public s_d;
    // slot 1
    // 20 bytes = 160 bits
    address public s_addr;
    // 96 bits
    uint64 public s_x;
    uint32 public s_y;

    function test_sstore() public {
        assembly {
            // Load 32 bytes from slot0
            let v := sload(0)

            // s_d | s_c | s_b | s_a
            // 32  | 32  | 64  | 128 bits

            // Set s_a = 1
            // mask = all 1s at and to the left of 128 bit counting from right
            //        111 ... 111 | 000 ... 000
            //                    |    128 bits
            let mask_a := not(sub(shl(128, 1), 1))
            // Set left most 128 bits to 0
            v := and(v, mask_a)
            // Set s_a = 1
            v := or(v, 1)

            // Set s_b = 2
            // mask = 111...111 | 000 ... 000 | 111 ... 111
            //                  |     64 bits |    128 bits
            let mask_b := not(shl(128, sub(shl(64, 1), 1)))
            // Clear previous value of s_b by setting bits (128 to 191 bits) to 0
            v := and(v, mask_b)
            v := or(v, shl(128, 2))

            // Set s_c = 3
            // mask = 111...111 | 000...000 | 111 ... 111 | 111 ... 111
            //                  |   32 bits |     64 bits |    128 bits
            let mask_c := not(shl(192, sub(shl(32, 1), 1)))
            // Clear previous value of s_c by setting bits (192 to 223 bits) to 0
            v := and(v, mask_c)
            v := or(v, shl(192, 3))

            // Set s_d = 4
            // mask = 000...000 | 111...111 | 111 ... 111 | 111 ... 111
            //                  |   32 bits |     64 bits |    128 bits
            let mask_d := not(shl(224, sub(shl(32, 1), 1)))
            // Clear previous value of s_d by setting bits (224 to 255 bits) to 0
            v := and(v, mask_d)
            v := or(v, shl(224, 4))

            // Store new value to slot0
            sstore(0, v)
        }
    }

    function test_slot_0_offset()
        public
        view
        returns (
            uint256 a_offset,
            uint256 b_offset,
            uint256 c_offset,
            uint256 d_offset
        )
    {
        // a_offset =  0 =  0 * 8 =   0 bits
        // b_offset = 16 = 16 * 8 = 128 bits
        // c_offset = 24 = 24 * 8 = 192 bits
        // d_offset = 28 = 28 * 8 = 224 bits
        assembly {
            a_offset := s_a.offset
            b_offset := s_b.offset
            c_offset := s_c.offset
            d_offset := s_d.offset
        }
    }

    function test_slot_1_offset()
        public
        view
        returns (uint256 addr_offset, uint256 x_offset, uint256 y_offset)
    {
        // addr_offset = 0
        // x_offset = 20
        // y_offset = 28
        assembly {
            addr_offset := s_addr.offset
            x_offset := s_x.offset
            y_offset := s_y.offset
        }
    }

    // slot and offset
    function test_sstore_using_offset() public {
        // a_offset =  0 =  0 * 8 =   0 bits
        // b_offset = 16 = 16 * 8 = 128 bits
        // c_offset = 24 = 24 * 8 = 192 bits
        // d_offset = 28 = 28 * 8 = 224 bits
        assembly {
            // Load 32 bytes from slot0
            let v := sload(s_a.slot)

            // s_d | s_c | s_b | s_a
            // 32  | 32  | 64  | 128 bits

            // Set s_a = 11
            // mask = all 1s at and to the left of 128 bit counting from right
            //        111 ... 111 | 000 ... 000
            //                    |    128 bits
            let mask_a := not(sub(shl(128, 1), 1))
            // Set left most 128 bits to 0
            v := and(v, mask_a)
            // Set s_a = 1
            v := or(v, 11)

            // Set s_b = 22
            // mask = 111...111 | 000 ... 000 | 111 ... 111
            //                  |     64 bits |    128 bits
            let mask_b := not(shl(s_b.offset, sub(shl(64, 1), 1)))
            // Clear previous value of s_b by setting bits (128 to 191 bits) to 0
            v := and(v, mask_b)
            v := or(v, shl(s_b.offset, 22))

            // Set s_c = 33
            // mask = 111...111 | 000...000 | 111 ... 111 | 111 ... 111
            //                  |   32 bits |     64 bits |    128 bits
            let mask_c := not(shl(s_c.offset, sub(shl(32, 1), 1)))
            // Clear previous value of s_c by setting bits (192 to 223 bits) to 0
            v := and(v, mask_c)
            v := or(v, shl(s_c.offset, 33))

            // Set s_d = 44
            // mask = 000...000 | 111...111 | 111 ... 111 | 111 ... 111
            //                  |   32 bits |     64 bits |    128 bits
            let mask_d := not(shl(s_d.offset, sub(shl(32, 1), 1)))
            // Clear previous value of s_d by setting bits (224 to 255 bits) to 0
            v := and(v, mask_d)
            v := or(v, shl(s_d.offset, 44))

            // Store new value to slot0
            sstore(s_a.slot, v)
        }
    }
}

// Struct
contract EVMStorageStruct {
    struct SingleSlot {
        uint128 x;
        uint64 y;
        uint64 z;
    }

    struct MultipleSlots {
        uint256 a;
        uint256 b;
        uint256 c;
    }

    // slot 0
    SingleSlot public single = SingleSlot({x: 1, y: 2, z: 3});
    // slot 1, 2, 3
    MultipleSlots public multi = MultipleSlots({a: 11, b: 22, c: 33});

    function test_get_single_slot_struct()
        public
        view
        returns (uint128 x, uint64 y, uint64 z)
    {
        assembly {
            let s := sload(0)
            // left 128 bits will be cut off when casted to uint128
            x := s

            // 000 ... 000 | 111 ... 111
            //             | 64 bits
            let mask_64 := sub(shl(64, 1), 1)

            y := and(mask_64, shr(128, s))
            z := and(mask_64, shr(192, s))
        }
    }

    function test_get_multiple_slots_struct()
        public
        view
        returns (uint256 a, uint256 b, uint256 c)
    {
        assembly {
            a := sload(1)
            b := sload(2)
            c := sload(3)
        }
    }
}

contract EVMStorageConstants {
    // slot 0
    uint256 public s0 = 1;
    // Constants and immutables don't use storage
    uint256 public constant X = 123;
    address public immutable owner;
    // slot 1
    uint256 public s1 = 2;

    constructor() {
        owner = msg.sender;
    }

    function test_get_slots() public view returns (uint256 v0, uint256 v1) {
        assembly {
            v0 := sload(0)
            v1 := sload(1)
        }
    }
}

contract EVMStorageFixedArray {
    // Fixed array with elements <= 32 bytes, slot of element = slot of array declaration + index of array element
    // slots 0, 1, 2
    uint256[3] private arr_0 = [1, 2, 3];
    // slots 3, 4, 5
    uint256[3] private arr_1 = [4, 5, 6];
    // slot + packed index
    // slots 6, 6, 7, 7, 8
    uint128[5] private arr_2 = [7, 8, 9, 10, 11];

    function test_arr_0(uint256 i) public view returns (uint256 v) {
        assembly {
            // arr_0 starts from slot 0
            v := sload(add(0, i))
        }
    }

    function test_arr_1(uint256 i) public view returns (uint256 v) {
        assembly {
            // arr_1 starts from slot 3
            v := sload(add(3, i))
        }
    }

    function test_arr_2(uint256 i) public view returns (uint128 v) {
        assembly {
            // arr_2 starts from slot 6
            let b32 := sload(add(6, div(i, 2)))
            // slot 6 = 1st element | 0th element
            // slot 7 = 3rd element | 2nd element
            // slot 8 = 000 ... 000 | 4th element

            // i is even => get right 128 bits => cast bytes32 to uint128 (cut off left 128 bits)
            // i is odd  => get left 128 bits  => shift right 128 bits

            switch mod(i, 2)
            case 1 { v := shr(128, b32) }
            default { v := b32 }
        }
    }
}

contract EVMStorageDynamicArrays {
    // slot of element = keccak256(slot where this array is declared) + index of element
    // keccak256(0) + index
    uint256[] private arr = [11, 22, 33];

    function test_arr(uint256 i) public view returns (uint256 v, uint256 len) {
        uint256 slot = 0;
        bytes32 start = keccak256(abi.encode(slot));

        assembly {
            len := sload(slot)
            v := sload(add(start, i))
        }
    }
}

// contract Mapping {
//     // location = keccack256(key, slot)
//     mapping(address => uint256) public map;

//     function test() public {
//         map[address(1)] = 2;

//         uint256 key = uint256(uint160(address(1)));
//         uint256 slot = 0;
//         bytes32 loc = keccak256(abi.encode(key, slot));
//         uint256 val;

//         assembly {
//             val := sload(loc)
//         }

//         console2.log("v", val);
//     }
// }

// contract NestedMapping {
//     // key0 => key1 => val
//     // location = keccak256(key1, keccack256(key0, slot))
//     mapping(address => mapping(address => uint256)) public map;

//     function test() public {
//         map[address(1)][address(2)] = 3;

//         uint256 key0 = uint256(uint160(address(1)));
//         uint256 key1 = uint256(uint160(address(2)));
//         uint256 slot = 0;

//         bytes32 loc =
//             keccak256(abi.encode(key1, keccak256(abi.encode(key0, slot))));
//         uint256 val;

//         assembly {
//             val := sload(loc)
//         }

//         console2.log("v", val);
//     }
// }

// contract MappingArray {
//     // mapping -> keccak256(key, slot)
//     // array -> keccak256(slot) + index
//     // mapping -> array -> keccak256(keccak256(key, 0)) + index

//     mapping(address => uint256[]) public map;

//     function test() public {
//         map[address(0xa)].push(1);
//         map[address(0xa)].push(2);
//         map[address(0xa)].push(3);
//         map[address(0xa)].push(4);
//         map[address(0xa)].push(5);

//         address map_key = address(0xa);
//         uint256 arr_index = 1;

//         uint256 map_slot = 0;
//         bytes32 map_hash = keccak256(abi.encode(map_key, map_slot));
//         bytes32 arr_hash = keccak256(abi.encode(map_hash));

//         uint256 val;
//         uint256 len;

//         assembly {
//             len := sload(map_hash)
//             val := sload(add(arr_hash, arr_index))
//         }

//         console2.log("len", len);
//         console2.log("v", val);
//     }
// }
