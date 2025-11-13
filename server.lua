local RSGCore = exports['rsg-core']:GetCoreObject()

-- Track overdue warnings
local overdueWarnings = {}

-- Check for overdue payments (runs every hour)
CreateThread(function()
    while true do
        Wait(3600000) -- 1 hour
        CheckOverduePayments()
    end
end)

-- Send payment reminders (runs every 6 hours)
CreateThread(function()
    while true do
        Wait(21600000) -- 6 hours
        SendPaymentReminders()
    end
end)

function CheckOverduePayments()
    MySQL.query('SELECT * FROM player_loans WHERE status = ? AND next_payment_due < NOW()', {
        'active'
    }, function(overdueLoans)
        for _, loan in pairs(overdueLoans) do
            local daysOverdue = math.floor((os.time() - os.time(os.date("*t", os.time{year=string.sub(loan.next_payment_due,1,4), month=string.sub(loan.next_payment_due,6,7), day=string.sub(loan.next_payment_due,9,10)}))) / 86400)
            
            -- Initialize warning count
            overdueWarnings[loan.id] = overdueWarnings[loan.id] or 0
            
            -- Escalating consequences based on days overdue
            if daysOverdue >= 30 then
                -- 30+ days: Send to collections (major consequences)
                HandleCollections(loan)
            elseif daysOverdue >= 21 then
                -- 21-29 days: Final warning
                HandleFinalWarning(loan, daysOverdue)
            elseif daysOverdue >= 14 then
                -- 14-20 days: Second warning + larger penalty
                HandleSecondWarning(loan, daysOverdue)
            elseif daysOverdue >= 7 then
                -- 7-13 days: First warning + medium penalty
                HandleFirstWarning(loan, daysOverdue)
            elseif daysOverdue >= 1 then
                -- 1-6 days: Late fee only
                HandleLateFee(loan, daysOverdue)
            end
        end
    end)
end

-- 1-6 days overdue: Apply late fee
function HandleLateFee(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 1 then return end -- Already processed
    
    local lateFee = math.ceil(loan.weekly_payment * 0.10) -- 10% late fee
    local newBalance = loan.remaining_balance + lateFee
    
    MySQL.update('UPDATE player_loans SET remaining_balance = ? WHERE id = ?', {
        newBalance,
        loan.id
    })
    
    overdueWarnings[loan.id] = 1
    
    local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
    if Player then
        SendLoanLetter(Player.PlayerData.source, {
            title = 'PAYMENT OVERDUE',
            content = string.format([[
NOTICE: Payment Overdue

Your loan payment was due %d day(s) ago.

Late Fee Applied: $%d
New Balance: $%d
Weekly Payment: $%d

Please make a payment immediately.

Continued non-payment will result in additional penalties.

- %s
            ]], daysOverdue, lateFee, newBalance, loan.weekly_payment, Config.LetterSettings.Author)
        })
    end
end

-- 7-13 days overdue: First warning + medium penalty
function HandleFirstWarning(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 2 then return end
    
    local additionalFee = math.ceil(loan.weekly_payment * 0.15) -- Additional 15% fee
    local newBalance = loan.remaining_balance + additionalFee
    
    MySQL.update('UPDATE player_loans SET remaining_balance = ? WHERE id = ?', {
        newBalance,
        loan.id
    })
    
    overdueWarnings[loan.id] = 2
    
    local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
    if Player then
        SendLoanLetter(Player.PlayerData.source, {
            title = '⚠️ FIRST WARNING',
            content = string.format([[
URGENT: FIRST WARNING

Your payment is now %d days overdue.

Additional Penalty: $%d
Current Balance: $%d
Required Payment: $%d

CONSEQUENCES OF CONTINUED NON-PAYMENT:
- Additional fees every 7 days
- Loan sent to collections after 30 days
- Potential jail time for debt evasion

Pay immediately at any bank location.

- %s
            ]], daysOverdue, additionalFee, newBalance, loan.weekly_payment, Config.LetterSettings.Author)
        })
    end
end

-- 14-20 days overdue: Second warning + larger penalty
function HandleSecondWarning(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 3 then return end
    
    local additionalFee = math.ceil(loan.weekly_payment * 0.25) -- Additional 25% fee
    local newBalance = loan.remaining_balance + additionalFee
    
    MySQL.update('UPDATE player_loans SET remaining_balance = ? WHERE id = ?', {
        newBalance,
        loan.id
    })
    
    overdueWarnings[loan.id] = 3
    
    local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
    if Player then
        -- Remove some money if they have it
        if Player.PlayerData.money.cash >= loan.weekly_payment then
            Player.Functions.RemoveMoney('cash', loan.weekly_payment, "loan-auto-deduction")
            newBalance = newBalance - loan.weekly_payment
            
            MySQL.update('UPDATE player_loans SET remaining_balance = ?, payments_made = payments_made + 1 WHERE id = ?', {
                newBalance,
                loan.id
            })
            
            TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                title = 'Automatic Payment',
                description = 'Bank collected $' .. loan.weekly_payment .. ' from your cash',
                type = 'warning',
                duration = 10000
            })
        end
        
        SendLoanLetter(Player.PlayerData.source, {
            title = '⚠️⚠️ SECOND WARNING',
            content = string.format([[
SERIOUS WARNING: %d Days Overdue

Your loan is severely overdue.

Additional Penalty: $%d
Current Balance: $%d

The bank will now attempt to collect payment directly from any cash you carry.

If payment is not received within 10 days, your loan will be sent to collections and you may face jail time.

- %s
            ]], daysOverdue, additionalFee, newBalance, Config.LetterSettings.Author)
        })
    end
end

-- 21-29 days overdue: Final warning
function HandleFinalWarning(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 4 then return end
    
    local hugeFee = math.ceil(loan.weekly_payment * 0.50) -- 50% penalty
    local newBalance = loan.remaining_balance + hugeFee
    
    MySQL.update('UPDATE player_loans SET remaining_balance = ? WHERE id = ?', {
        newBalance,
        loan.id
    })
    
    overdueWarnings[loan.id] = 4
    
    local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
    if Player then
        SendLoanLetter(Player.PlayerData.source, {
            title = '🚨 FINAL WARNING 🚨',
            content = string.format([[
FINAL NOTICE: %d Days Overdue

This is your FINAL WARNING.

Massive Penalty Applied: $%d
Total Balance: $%d

Your loan will be sent to COLLECTIONS in less than 10 days.

COLLECTIONS CONSEQUENCES:
- Arrest warrant issued
- Jail time for debt evasion
- All assets seized
- Unable to get future loans

Pay immediately to avoid legal action!

- %s
            ]], daysOverdue, hugeFee, newBalance, Config.LetterSettings.Author)
        })
    end
end

-- 30+ days overdue: Collections (severe consequences)
function HandleCollections(loan)
    if overdueWarnings[loan.id] >= 5 then return end
    
    MySQL.update('UPDATE player_loans SET status = ? WHERE id = ?', {
        'collections',
        loan.id
    })
    
    overdueWarnings[loan.id] = 5
    
    local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
    if Player then
        local src = Player.PlayerData.source
        
        -- Take all their cash
        local cashAmount = Player.PlayerData.money.cash
        if cashAmount > 0 then
            Player.Functions.RemoveMoney('cash', cashAmount, "loan-collections")
            
            -- Apply to loan balance
            local newBalance = loan.remaining_balance - cashAmount
            MySQL.update('UPDATE player_loans SET remaining_balance = ? WHERE id = ?', {
                math.max(0, newBalance),
                loan.id
            })
        end
        
        -- Send to jail (if you have a jail system)
        -- TriggerEvent('rsg-jail:server:JailPlayer', src, 30, "Debt Evasion")
        
        SendLoanLetter(src, {
            title = '🚨 SENT TO COLLECTIONS 🚨',
            content = string.format([[
COLLECTIONS NOTICE

Your loan has been sent to collections for non-payment.

ACTIONS TAKEN:
- All cash seized ($%d)
- Arrest warrant issued
- Cannot apply for future loans
- Remaining balance: $%d

You must pay the remaining balance at a bank before you can conduct any business.

This is a serious offense.

- Collections Agency
            ]], cashAmount, math.max(0, loan.remaining_balance - cashAmount))
        })
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚨 LOAN IN COLLECTIONS',
            description = 'Your loan is in collections. All cash seized. Visit a bank immediately.',
            type = 'error',
            duration = 15000
        })
        
        -- Optional: Notify police
        -- TriggerEvent('rsg-lawman:server:SendAlert', 'Debt Evasion Warrant', Player.PlayerData.charinfo)
    end
end

function SendPaymentReminders()
    local reminderDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.LetterSettings.ReminderDaysBefore * 24 * 60 * 60))
    
    MySQL.query('SELECT * FROM player_loans WHERE status = ? AND next_payment_due <= ? AND next_payment_due > NOW()', {
        'active',
        reminderDate
    }, function(upcomingLoans)
        for _, loan in pairs(upcomingLoans) do
            local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
            
            if Player then
                SendLoanLetter(Player.PlayerData.source, {
                    title = 'Payment Reminder',
                    content = string.format([[
Payment Reminder

This is a friendly reminder that your loan payment is due soon.

Payment Amount: $%d
Due Date: %s
Remaining Balance: $%d

Please ensure you have sufficient funds available.

- %s
                    ]], loan.weekly_payment, loan.next_payment_due, loan.remaining_balance, Config.LetterSettings.Author)
                })
            end
        end
    end)
end
