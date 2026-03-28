local M = {}

function M.assert_contract_shape(contract, expected_name)
    assert(type(contract) == "table", "contract must be a table")
    assert(contract.name == expected_name, "unexpected contract name")
    assert(contract.version == "phase3-contract", "unexpected contract version")
    assert(contract.deterministic == true, "contract must be deterministic")
    assert(type(contract.api) == "table", "contract api must be a table")
end

function M.assert_api_operation(contract, operation_name)
    local operation = contract.api[operation_name]
    assert(type(operation) == "table", "operation table missing: " .. operation_name)
    assert(type(operation.input) == "table", "operation input missing: " .. operation_name)
    assert(type(operation.output) == "table", "operation output missing: " .. operation_name)
end

return M
