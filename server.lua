local RSGCore = exports['rsg-core']:GetCoreObject()

RSGCore.Functions.CreateUseableItem("letter", function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    if item and item.info then
        TriggerClientEvent('bankloan:client:readLetter', source, {
            title = item.info.title or "Letter",
            content = item.info.content or "This letter appears to be blank.",
            author = item.info.author or "Unknown"
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'This letter appears to be damaged',
            type = 'error'
        })
    end
end)


-- Calculate interest rate based on loan amount
local function GetInterestRate(amount)
    local rate = 5
    for threshold, interestRate in pairs(Config.LoanSettings.InterestRates) do
        if amount >= threshold then
            rate = interestRate
        end
    end
    return rate
end

-- Apply for loan
RegisterNetEvent('bankloan:server:applyLoan', function(amount, numPayments)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    -- Validate inputs
    if amount < Config.LoanSettings.MinLoanAmount or amount > Config.LoanSettings.MaxLoanAmount then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Bank',
            description = 'Invalid loan amount',
            type = 'error'
        })
        return
    end

    -- Check for existing active loans
    MySQL.query('SELECT COUNT(*) as count FROM player_loans WHERE citizenid = ? AND status = ?', {
        Player.PlayerData.citizenid,
        'active'
    }, function(result)
        if result[1].count >= Config.LoanSettings.MaxActiveLoans then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Bank',
                description = 'You already have an active loan',
                type = 'error'
            })
            return
        end

        local interestRate = GetInterestRate(amount)
        local interestAmount = amount * (interestRate / 100)
        local totalAmount = amount + interestAmount
        local weeklyPayment = math.ceil(totalAmount / numPayments)
        local nextPaymentDue = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.LoanSettings.PaymentFrequency * 24 * 60 * 60))

        -- Create loan
        MySQL.insert('INSERT INTO player_loans (citizenid, loan_amount, remaining_balance, weekly_payment, interest_rate, total_payments, next_payment_due) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            Player.PlayerData.citizenid,
            amount,
            totalAmount,
            weeklyPayment,
            interestRate,
            numPayments,
            nextPaymentDue
        }, function(loanId)
            -- Give money to player
            Player.Functions.AddMoney('cash', amount)

            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Loan Approved',
                description = string.format('Loan of $%d approved!\nWeekly payment: $%d\nInterest rate: %.1f%%', amount, weeklyPayment, interestRate),
                type = 'success',
                duration = 10000
            })

            -- Send confirmation letter
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

Best regards,
%s
                ]], amount, interestRate, totalAmount, weeklyPayment, numPayments, nextPaymentDue, Config.LetterSettings.Author)
            })
        end)
    end)
end)

-- Get active loans
RegisterNetEvent('bankloan:server:getActiveLoans', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    MySQL.query('SELECT * FROM player_loans WHERE citizenid = ? AND status = ?', {
        Player.PlayerData.citizenid,
        'active'
    }, function(result)
        TriggerClientEvent('bankloan:client:showLoanDetails', src, result)
    end)
end)

-- Make payment
RegisterNetEvent('bankloan:server:makePayment', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    MySQL.query('SELECT * FROM player_loans WHERE citizenid = ? AND status = ? ORDER BY next_payment_due ASC LIMIT 1', {
        Player.PlayerData.citizenid,
        'active'
    }, function(result)
        if not result[1] then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Bank',
                description = 'No active loans found',
                type = 'error'
            })
            return
        end

        local loan = result[1]
        local paymentAmount = loan.weekly_payment

        -- Check if player has enough money
        if Player.PlayerData.money.cash < paymentAmount then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Insufficient Funds',
                description = string.format('You need $%d to make this payment', paymentAmount),
                type = 'error'
            })
            return
        end

        -- Process payment
        Player.Functions.RemoveMoney('cash', paymentAmount)
        
        local newBalance = loan.remaining_balance - paymentAmount
        local newPaymentsMade = loan.payments_made + 1
        
        if newBalance <= 0 or newPaymentsMade >= loan.total_payments then
            -- Loan paid off
            MySQL.update('UPDATE player_loans SET remaining_balance = 0, payments_made = ?, status = ? WHERE id = ?', {
                newPaymentsMade,
                'paid',
                loan.id
            })

            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Loan Paid Off',
                description = 'Congratulations! Your loan has been fully paid',
                type = 'success'
            })

            SendLoanLetter(src, {
                title = 'Loan Completion',
                content = 'Congratulations! Your loan has been fully repaid. Thank you for your business.\n\n- ' .. Config.LetterSettings.Author
            })
        else
            -- Update loan
            local nextPaymentDue = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.LoanSettings.PaymentFrequency * 24 * 60 * 60))
            
            MySQL.update('UPDATE player_loans SET remaining_balance = ?, payments_made = ?, next_payment_due = ? WHERE id = ?', {
                newBalance,
                newPaymentsMade,
                nextPaymentDue,
                loan.id
            })

            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Payment Received',
                description = string.format('Payment of $%d received\nRemaining balance: $%d', paymentAmount, newBalance),
                type = 'success'
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
        author = Config.LetterSettings.Author
    }

    Player.Functions.AddItem(Config.LetterSettings.LetterItem, 1, false, info)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Mail Received',
        description = 'You have received a letter from the bank',
        type = 'inform'
    })
end

exports('SendLoanLetter', SendLoanLetter)