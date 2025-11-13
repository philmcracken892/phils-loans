local RSGCore = exports['rsg-core']:GetCoreObject()


CreateThread(function()
    for _, bank in pairs(Config.BankLocations) do
        if bank.blip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, bank.coords.x, bank.coords.y, bank.coords.z)
            SetBlipSprite(blip, -1896206456, 1)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, bank.name)
        end
    end
end)


CreateThread(function()
    for i, bank in pairs(Config.BankLocations) do
        exports['rsg-core']:createPrompt(
            'bank_loan_' .. i,
            bank.coords,
            0xD9D0E1C0,
            'Open Bank Menu',
            {
                type = 'client',
                event = 'bankloan:client:openMenu',
                args = {}
            },
            2.0
        )
    end
end)


RegisterNetEvent('bankloan:client:openMenu', function()
    lib.registerContext({
        id = 'bank_main_menu',
        title = 'Bank Services',
        options = {
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
       
        local displayDate = loan.next_payment_due_formatted or "Unknown"
        
       
        local statusText = loan.status or "Unknown"
        local statusIcon = 'fa-solid fa-file-invoice-dollar'
        
        if loan.status == 'collections' then
            statusText = '?? COLLECTIONS'
            statusIcon = 'fa-solid fa-triangle-exclamation'
        elseif loan.status == 'active' then
            statusText = 'Active'
            statusIcon = 'fa-solid fa-circle-check'
        elseif loan.status == 'paid' then
            statusText = 'Paid Off'
            statusIcon = 'fa-solid fa-check-circle'
        end
        
        table.insert(options, {
            title = string.format('Loan #%d - %s', loan.id, statusText),
            description = string.format(
                'Amount Borrowed: $%d\nBalance Remaining: $%d\nWeekly Payment: $%d\n\nPayments: %d of %d completed\nInterest Rate: %.1f%%\n\nNext Payment Due:\n%s',
                loan.loan_amount,
                loan.remaining_balance,
                loan.weekly_payment,
                loan.payments_made,
                loan.total_payments,
                loan.interest_rate,
                displayDate
            ),
            icon = statusIcon,
        })
    end

   
    table.insert(options, {
        title = 'Back to Bank Menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            TriggerEvent('bankloan:client:openMenu')
        end
    })

    lib.registerContext({
        id = 'loan_details',
        title = 'Your Loan Details',
        options = options
    })

    lib.showContext('loan_details')
end)


RegisterNetEvent('bankloan:client:readLetter', function(letterData)
    if not letterData or not letterData.title or not letterData.content then
        lib.notify({
            title = 'Error',
            description = 'Invalid letter data',
            type = 'error'
        })
        return
    end
    
   
    local contentLines = {}
    for line in letterData.content:gmatch("[^\n]+") do
        if line and line ~= "" then
            table.insert(contentLines, {
                title = line,
                readOnly = true
            })
        end
    end
    
    
    local options = {
        {
            title = 'From: ' .. (letterData.author or 'Unknown'),
            icon = 'fa-solid fa-user',
            readOnly = true
        }
    }
    
    
    for _, line in ipairs(contentLines) do
        table.insert(options, line)
    end
    
    
    table.insert(options, {
        title = 'Close Letter',
        icon = 'fa-solid fa-times-circle',
        onSelect = function()
            lib.hideContext()
        end
    })
    
    lib.registerContext({
        id = 'read_letter',
        title = '?? ' .. letterData.title,
        options = options
    })
    
    lib.showContext('read_letter')
end)

