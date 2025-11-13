local RSGCore = exports['rsg-core']:GetCoreObject()

-- Create blips for banks
CreateThread(function()
    for _, bank in pairs(Config.BankLocations) do
        if bank.blip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, bank.coords.x, bank.coords.y, bank.coords.z)
            SetBlipSprite(blip, -1896206456, 1)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, bank.name)
        end
    end
end)

-- Bank interaction
CreateThread(function()
    for _, bank in pairs(Config.BankLocations) do
        exports['rsg-core']:createPrompt(
            'bank_loan_' .. _,
            bank.coords,
            0xD9D0E1C0, -- space key
            'Open Loan Menu',
            {
                type = 'client',
                event = 'bankloan:client:openMenu',
                args = {}
            },
            2.0
        )
    end
end)

-- Open bank menu
RegisterNetEvent('bankloan:client:openMenu', function()
    local options = {
        {
            title = 'Apply for Loan',
            description = 'Request a loan from the bank',
            icon = 'fa-solid fa-hand-holding-dollar',
            onSelect = function()
                OpenLoanApplication()
            end
        },
        {
            title = 'View Active Loans',
            description = 'Check your current loans',
            icon = 'fa-solid fa-file-invoice-dollar',
            onSelect = function()
                TriggerServerEvent('bankloan:server:getActiveLoans')
            end
        },
        {
            title = 'Make Payment',
            description = 'Pay off your loan',
            icon = 'fa-solid fa-money-bill-wave',
            onSelect = function()
                TriggerServerEvent('bankloan:server:makePayment')
            end
        }
    }

    lib.registerContext({
        id = 'bank_main_menu',
        title = 'Loan Services',
        options = options
    })

    lib.showContext('bank_main_menu')
end)

function OpenLoanApplication()
    local input = lib.inputDialog('Loan Application', {
        {
            type = 'number',
            label = 'Loan Amount',
            description = 'Enter amount ($' .. Config.LoanSettings.MinLoanAmount .. ' - $' .. Config.LoanSettings.MaxLoanAmount .. ')',
            required = true,
            min = Config.LoanSettings.MinLoanAmount,
            max = Config.LoanSettings.MaxLoanAmount
        },
        {
            type = 'select',
            label = 'Payment Plan',
            description = 'Select number of payments',
            required = true,
            options = {
                {value = 4, label = '4 Payments (1 Month)'},
                {value = 8, label = '8 Payments (2 Months)'},
                {value = 12, label = '12 Payments (3 Months)'},
            }
        }
    })

    if input then
        TriggerServerEvent('bankloan:server:applyLoan', input[1], input[2])
    end
end

RegisterNetEvent('bankloan:client:showLoanDetails', function(loans)
    if not loans or #loans == 0 then
        lib.notify({
            title = 'Bank',
            description = 'You have no active loans',
            type = 'inform'
        })
        return
    end

    local options = {}
    for _, loan in pairs(loans) do
        local interestAmount = loan.loan_amount * (loan.interest_rate / 100)
        local totalAmount = loan.loan_amount + interestAmount
        
        table.insert(options, {
            title = 'Loan #' .. loan.id,
            description = string.format(
                'Amount: $%d | Balance: $%d\nWeekly Payment: $%d\nPayments: %d/%d\nNext Due: %s',
                loan.loan_amount,
                loan.remaining_balance,
                loan.weekly_payment,
                loan.payments_made,
                loan.total_payments,
                loan.next_payment_due
            ),
            icon = 'fa-solid fa-receipt',
        })
    end

    lib.registerContext({
        id = 'loan_details',
        title = 'Your Active Loans',
        menu = 'bank_main_menu',
        options = options
    })

    lib.showContext('loan_details')
end)

-- Read loan letter
RegisterNetEvent('bankloan:client:readLetter', function(letterData)
    lib.alertDialog({
        header = letterData.title,
        content = letterData.content,
        centered = true,
        cancel = false,
        labels = {
            confirm = 'Close'
        }
    })
end)