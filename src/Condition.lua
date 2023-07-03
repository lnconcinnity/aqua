return function(condition: any | boolean | nil, ok: () -> ())
    if condition then
        ok()
    end
    return condition
end