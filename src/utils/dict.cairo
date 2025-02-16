%lang starknet

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict import dict_write, dict_squash
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import unsigned_div_rem

// @dev Copy a default_dict
// @param start The pointer to the beginning of the dict
// @param self The pointer to the end of the dict
func default_dict_copy{range_check_ptr}(start: DictAccess*, end: DictAccess*) -> (
    DictAccess*, DictAccess*
) {
    alloc_locals;
    let (squashed_start, squashed_end) = dict_squash(start, end);
    let dict_len = squashed_end - squashed_start;

    if (dict_len == 0) {
        tempvar default_value = 0;
    } else {
        tempvar default_value = squashed_start.prev_value;
    }

    let (local new_start) = default_dict_new(default_value);
    let new_ptr = new_start;

    if (dict_len == 0) {
        return (new_start, new_ptr);
    }

    tempvar range_check_ptr = range_check_ptr;
    tempvar squashed_start = squashed_start;
    tempvar dict_len = dict_len;
    tempvar new_ptr = new_ptr;

    loop:
    let range_check_ptr = [ap - 4];
    let squashed_start = cast([ap - 3], DictAccess*);
    let dict_len = [ap - 2];
    let new_ptr = cast([ap - 1], DictAccess*);

    let key = [squashed_start].key;
    let new_value = [squashed_start].new_value;

    dict_write{dict_ptr=new_ptr}(key=key, new_value=new_value);

    tempvar range_check_ptr = range_check_ptr;
    tempvar squashed_start = squashed_start + DictAccess.SIZE;
    tempvar dict_len = dict_len - DictAccess.SIZE;
    tempvar new_ptr = new_ptr;

    static_assert range_check_ptr == [ap - 4];
    static_assert squashed_start == [ap - 3];
    static_assert dict_len == [ap - 2];
    static_assert new_ptr == [ap - 1];

    jmp loop if dict_len != 0;

    return (new_start, new_ptr);
}

func dict_keys{range_check_ptr}(dict_start: DictAccess*, dict_end: DictAccess*) -> (
    keys_len: felt, keys: felt*
) {
    alloc_locals;
    let (local keys_start: felt*) = alloc();
    let dict_len = dict_end - dict_start;
    let (local keys_len, _) = unsigned_div_rem(dict_len, DictAccess.SIZE);

    if (dict_len == 0) {
        return (keys_len, keys_start);
    }

    tempvar range_check_ptr = range_check_ptr;
    tempvar keys = keys_start;
    tempvar len = keys_len;
    tempvar dict = dict_start;

    loop:
    let range_check_ptr = [ap - 4];
    let keys = cast([ap - 3], felt*);
    let len = [ap - 2];
    let dict = cast([ap - 1], DictAccess*);

    assert [keys] = dict.key;
    tempvar range_check_ptr = range_check_ptr;
    tempvar keys = keys + 1;
    tempvar len = len - 1;
    tempvar dict = dict + DictAccess.SIZE;

    static_assert range_check_ptr == [ap - 4];
    static_assert keys == [ap - 3];
    static_assert len == [ap - 2];
    static_assert dict == [ap - 1];

    jmp loop if len != 0;

    return (keys_len, keys_start);
}
