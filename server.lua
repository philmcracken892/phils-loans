local RSGCore = exports['rsg-core']:GetCoreObject()
RSGCore.Functions.CreateUseableItem("letter", function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not item or not item.info then return end
    
   
    TriggerClientEvent('bankloan:client:readLetter', source, {
        title = item.info.title or "Letter",
        content = item.info.content or "This letter appears to be blank.",
        author = item.info.author or "Unknown"
    })
    
    
    Player.Functions.RemoveItem('letter', 1, item.slot)
    TriggerClientEvent('inventory:client:ItemBox', source, RSGCore.Shared.Items['letter'], "remove")
end)

local function FormatTimestamp(timestamp)
    if not timestamp then
        return "Not set"
    end
    
   
    if type(timestamp) == "number" then
       
        if timestamp > 9999999999 then
            timestamp = math.floor(timestamp / 1000)
        end
        return os.date("%d/%m/%Y at %H:%M", timestamp)
    end
    
   
    if type(timestamp) == "string" then
        local year, month, day, hour, min = string.match(timestamp, "(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d)")
        if year then
            return string.format("%s/%s/%s at %s:%s", day, month, year, hour, min)
        end
    end
    
    return tostring(timestamp)
end


local function GetInterestRate(amount)
    local rate = 5
    for threshold, interestRate in pairs(Config.LoanSettings.InterestRates) do
        if amount >= threshold then
            rate = interestRate
        end
    end
    return rate
end


RegisterNetEvent('bankloan:server:applyLoan', function(amount, numPayments)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end

   
    if amount < Config.LoanSettings.MinLoanAmount or amount > Config.LoanSettings.MaxLoanAmount then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Bank',
            description = 'Invalid loan amount',
            type = 'error'
        })
        return
    end

   
    MySQL.query('SELECT COUNT(*) as count FROM player_loans WHERE citizenid = ? AND (status = ? OR status = ?)', {
        Player.PlayerData.citizenid,
        'active',
        'collections'
    }, function(result)
        if result and result[1] and result[1].count >= Config.LoanSettings.MaxActiveLoans then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Bank',
                description = 'You have an outstanding loan or debt in collections. Pay it off first.',
                type = 'error',
                duration = 8000
            })
            return
        end

        local interestRate = GetInterestRate(amount)
        local interestAmount = math.ceil(amount * (interestRate / 100))
        local totalAmount = amount + interestAmount
        local weeklyPayment = math.ceil(totalAmount / numPayments)
        
       
        local nextPaymentTimestamp = os.time() + (Config.LoanSettings.PaymentFrequency * 24 * 60 * 60)
        local nextPaymentDate = os.date('%Y-%m-%d %H:%M:%S', nextPaymentTimestamp)

       
        MySQL.insert('INSERT INTO player_loans (citizenid, loan_amount, remaining_balance, weekly_payment, interest_rate, total_payments, next_payment_due) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            Player.PlayerData.citizenid,
            amount,
            totalAmount,
            weeklyPayment,
            interestRate,
            numPayments,
            nextPaymentDate
        }, function(loanId)
            if loanId then
                
                Player.Functions.AddMoney('cash', amount)

                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Loan Approved',
                    description = string.format('Loan of $%d approved!\nWeekly payment: $%d\nInterest rate: %.1f%%', amount, weeklyPayment, interestRate),
                    type = 'success',
                    duration = 10000
                })

               
                local formattedDueDate = FormatTimestamp(nextPaymentTimestamp)
                
                SendLoanLetter(src, {
                    title = 'Loan Agreement',
                    content = string.format([[
Dear Valued Customer,

Your loan application has been approved!

Loan Amount: $%d
Interest Rate: %.1f%%
Total to Repay: $%d
Weekly Payment: $%d
Number of Payments: %d
First Payment Due: %s

Please ensure you have sufficient funds for each payment.

WARNING: Late payments incur penalties.
After 30 days overdue, your loan goes to collections.

Best regards,
%s
                    ]], amount, interestRate, totalAmount, weeklyPayment, numPayments, formattedDueDate, Config.LetterSettings.Author)
                })
            end
        end)
    end)
end)


RegisterNetEvent('bankloan:server:getActiveLoans', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    MySQL.query('SELECT * FROM player_loans WHERE citizenid = ? AND (status = ? OR status = ?)', {
        Player.PlayerData.citizenid,
        'active',
        'collections'
    }, function(result)
        if result then
            
            for i, loan in ipairs(result) do
                loan.next_payment_due_formatted = FormatTimestamp(loan.next_payment_due)
                loan.created_at_formatted = FormatTimestamp(loan.created_at)
            end
            
            TriggerClientEvent('bankloan:client:showLoanDetails', src, result)
        else
            TriggerClientEvent('bankloan:client:showLoanDetails', src, {})
        end
    end)
end)


RegisterNetEvent('bankloan:server:makePayment', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    MySQL.query('SELECT * FROM player_loans WHERE citizenid = ? AND (status = ? OR status = ?) ORDER BY next_payment_due ASC LIMIT 1', {
        Player.PlayerData.citizenid,
        'active',
        'collections'
    }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Bank',
                description = 'No active loans found',
                type = 'error'
            })
            return
        end

        local loan = result[1]
        local paymentAmount = loan.weekly_payment

       
        if loan.status == 'collections' then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Collections Account',
                description = string.format('Your account is in collections. Minimum payment: $%d', paymentAmount),
                type = 'warning',
                duration = 8000
            })
        end

       
        if Player.PlayerData.money.cash < paymentAmount then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Insufficient Funds',
                description = string.format('You need $%d cash to make this payment', paymentAmount),
                type = 'error'
            })
            return
        end

      
        Player.Functions.RemoveMoney('cash', paymentAmount, "loan-payment")
        
        local newBalance = loan.remaining_balance - paymentAmount
        local newPaymentsMade = loan.payments_made + 1
        
        if newBalance <= 0 or newPaymentsMade >= loan.total_payments then
            
            MySQL.update('UPDATE player_loans SET remaining_balance = 0, payments_made = ?, status = ? WHERE id = ?', {
                newPaymentsMade,
                'paid',
                loan.id
            })

            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Loan Paid Off',
                description = 'Congratulations! Your loan has been fully paid',
                type = 'success',
                duration = 8000
            })

            SendLoanLetter(src, {
                title = 'Loan Completion',
                content = string.format([[
Congratulations!

Your loan has been fully repaid.

Loan ID: #%d
Total Paid: $%d

Your account is now clear and you may apply for future loans.

Thank you for your business.

- %s
                ]], loan.id, loan.loan_amount + math.ceil(loan.loan_amount * loan.interest_rate / 100), Config.LetterSettings.Author)
            })
        else
            
            local newStatus = (loan.status == 'collections' and newBalance > 0) and 'active' or loan.status
            
            
            local nextPaymentTimestamp = os.time() + (Config.LoanSettings.PaymentFrequency * 24 * 60 * 60)
            local nextPaymentDate = os.date('%Y-%m-%d %H:%M:%S', nextPaymentTimestamp)
            
            MySQL.update('UPDATE player_loans SET remaining_balance = ?, payments_made = ?, next_payment_due = ?, status = ? WHERE id = ?', {
                newBalance,
                newPaymentsMade,
                nextPaymentDate,
                newStatus,
                loan.id
            })

            local extraMsg = ""
            if loan.status == 'collections' and newStatus == 'active' then
                extraMsg = "\n\nYour account has been restored to good standing!"
            end

            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Payment Received',
                description = string.format('Payment of $%d received\nRemaining balance: $%d%s', paymentAmount, newBalance, extraMsg),
                type = 'success',
                duration = 8000
            })
        end
    end)
end)

function SendLoanLetter(src, letterData)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local info = {
        title = letterData.title,
        content = letterData.content,
        author = letterData.author or Config.LetterSettings.Author
    }

   
    local success = Player.Functions.AddItem(Config.LetterSettings.LetterItem, 1, false, info)
    
    if success then
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.LetterSettings.LetterItem], "add")
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Mail Received',
            description = 'You have received a letter from the bank',
            type = 'inform'
        })
    else
       
        TriggerClientEvent('ox_lib:notify', src, {
            title = letterData.title,
            description = 'Check your mail',
            type = 'inform',
            duration = 8000
        })
        
        Wait(500)
        TriggerClientEvent('bankloan:client:readLetter', src, info)
    end
end

exports('SendLoanLetter', SendLoanLetter)

