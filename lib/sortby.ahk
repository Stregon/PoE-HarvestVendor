_clone(param_value) {
    if (isObject(param_value)) {
        return param_value.Clone()
    } else {
        return param_value
    }
}

_cloneDeep(param_array) {
    Objs := {}
    Obj := param_array.Clone()
    Objs[&param_array] := Obj ; Save this new array
    for key, value in Obj {
        if (isObject(value)) ; if it is a subarray
            Obj[key] := Objs[&value] ; if we already know of a refrence to this array
            ? Objs[&value] ; Then point it to the new array
            : _clone(value) ; Otherwise, clone this sub-array
    }
    return Obj
}

_internal_sort(param_collection, param_iteratees:="") {
    l_array := _cloneDeep(param_collection)

    ; associative arrays
    if (param_iteratees != "") {
        for Index, obj in l_array {
            value := obj[param_iteratees]
            if (!isNumber(value)) {
                value := StrReplace(value, "+", "#")
            }
            out .= value "+" Index "|" ; "+" allows for sort to work with just the value
            ; out will look like: value+index|value+index|
        }
        lastvalue := l_array[Index, param_iteratees]
    } else {
        ; regular arrays
        for Index, obj in l_array {
            value := obj
            if (!isNumber(obj)) {
                value := StrReplace(value, "+", "#")
            }
            out .= value "+" Index "|"
        }
        lastvalue := l_array[l_array.count()]
    }

    if (isNumber(lastvalue)) {
        sortType := "N"
    }
    stringTrimRight, out, out, 1 ; remove trailing |
    sort, out, % "D| " sortType
    arrStorage := []
    loop, parse, out, |
    {
        arrStorage.push(l_array[SubStr(A_LoopField, InStr(A_LoopField, "+") + 1)])
    }
    return arrStorage
}

sortBy(param_collection, param_iteratees:="__identity") {
    l_array := []

    ; create
    ; no param_iteratees
    if (param_iteratees == "__identity") {
        return _internal_sort(param_collection)
    }
    ; property
    if (isAlnum(param_iteratees)) {
        return _internal_sort(param_collection, param_iteratees)
    }
    ; own method or function
    ; if (isCallable(param_iteratees)) {
        ; for key, value in param_collection {
            ; l_array[A_Index] := {}
            ; l_array[A_Index].value := value
            ; l_array[A_Index].key := param_iteratees.call(value)
        ; }
        ; l_array := _internal_sort(l_array, "key")
        ; return this.map(l_array, "value")
    ; }
    ; shorthand/multiple keys
    if (isObject(param_iteratees)) {
        l_array := _cloneDeep(param_collection)
        ; sort the collection however many times is requested by the shorthand identity
        for key, value in param_iteratees {
            l_array := _internal_sort(l_array, value)
        }
        return l_array
    }
    return -1
}

isAlnum(param) {
    if (isObject(param)) {
        return false
    }
    if param is alnum
    {
        return true
    }
    return false
}

; isCallable(param) {
    ; fn := numGet(&(_ := Func("InStr").bind()), "Ptr")
    ; return (isFunc(param) || (isObject(param) && (numGet(&param, "Ptr") = fn)))
; }

isNumber(param) {
    if (isObject(param)) {
        return false
    }
    if param is number
    {
        return true
    }
    return false
}