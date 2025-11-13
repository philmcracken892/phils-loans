local RSGCore = exports['rsg-core']:GetCoreObject()


local overdueWarnings = {}


CreateThread(function()
    while true do
        Wait(3600000) -- 1 hour
        CheckOverduePayments()
    end
end)


CreateThread(function()
    while true do
        Wait(21600000) -- 6 hours
        SendPaymentReminders()
    end
end)


local function GetDaysOverdue(dueDate)
    local dueTime
    
    if type(dueDate) == "number" then
        dueTime = dueDate > 9999999999 and math.floor(dueDate / 1000) or dueDate
    elseif type(dueDate) == "string" then
        local year, month, day, hour, min, sec = string.match(dueDate, "(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d):(%d%d)")
        if year then
            dueTime = os.time{year=year, month=month, day=day, hour=hour, min=min, sec=sec}
        else
            return 0
        end
    else
        return 0
    end
    
    return math.floor((os.time() - dueTime) / 86400)
end

function CheckOverduePayments()
    MySQL.query('SELECT * FROM player_loans WHERE status = ? AND next_payment_due < NOW()', {
        'active'
    }, function(overdueLoans)
        if not overdueLoans or #overdueLoans == 0 then
            return
        end
        
        for _, loan in pairs(overdueLoans) do
            local daysOverdue = GetDaysOverdue(loan.next_payment_due)
            
            
            if not overdueWarnings[loan.id] then
                overdueWarnings[loan.id] = 0
            end
            
            
            if daysOverdue >= 30 then
                HandleCollections(loan, daysOverdue)
            elseif daysOverdue >= 21 then
                HandleFinalWarning(loan, daysOverdue)
            elseif daysOverdue >= 14 then
                HandleSecondWarning(loan, daysOverdue)
            elseif daysOverdue >= 7 then
                HandleFirstWarning(loan, daysOverdue)
            elseif daysOverdue >= 1 then
                HandleLateFee(loan, daysOverdue)
            end
        end
    end)
end


function HandleLateFee(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 1 then return end
    
    local lateFee = math.ceil(loan.weekly_payment * (Config.LoanSettings.LatePaymentPenalty / 100))
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

Please make a payment immediately at any bank.

Continued non-payment will result in additional penalties.

- %s
            ]], daysOverdue, lateFee, newBalance, loan.weekly_payment, Config.LetterSettings.Author)
        })
    end
end


function HandleFirstWarning(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 2 then return end
    
    local penalty = math.ceil(loan.weekly_payment * 0.15)
    local newBalance = loan.remaining_balance + penalty
    
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
- Automatic cash collection after 14 days
- Loan sent to collections after 30 days
- Possible jail time

Pay immediately at any bank location.

- %s
            ]], daysOverdue, penalty, newBalance, loan.weekly_payment, Config.LetterSettings.Author)
        })
    end
end


function HandleSecondWarning(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 3 then return end
    
    local penalty = math.ceil(loan.weekly_payment * 0.25)
    local newBalance = loan.remaining_balance + penalty
    
    MySQL.update('UPDATE player_loans SET remaining_balance = ? WHERE id = ?', {
        newBalance,
        loan.id
    })
    
    overdueWarnings[loan.id] = 3
    
    local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
    if Player then
        local cashCollected = 0
        
        
        if Config.LoanSettings.AutoDeductAfterDays and Player.PlayerData.money.cash >= loan.weekly_payment then
            cashCollected = loan.weekly_payment
            Player.Functions.RemoveMoney('cash', cashCollected, "loan-auto-collection")
            newBalance = newBalance - cashCollected
            
            local nextPaymentDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.LoanSettings.PaymentFrequency * 24 * 60 * 60))
            MySQL.update('UPDATE player_loans SET remaining_balance = ?, payments_made = payments_made + 1, next_payment_due = ? WHERE id = ?', {
                newBalance,
                nextPaymentDate,
                loan.id
            })
        end
        
        SendLoanLetter(Player.PlayerData.source, {
            title = '⚠️⚠️ SECOND WARNING',
            content = string.format([[
SERIOUS WARNING: %d Days Overdue

Your loan is severely overdue.

Additional Penalty: $%d
Cash Auto-Collected: $%d
Current Balance: $%d

The bank will now automatically collect payments from any cash you carry.

If payment is not received within 10 days, your loan will be sent to COLLECTIONS and you may face jail time.

- %s
            ]], daysOverdue, penalty, cashCollected, newBalance, Config.LetterSettings.Author)
        })
        
        if cashCollected > 0 then
            TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                title = 'Bank Auto-Collection',
                description = 'Bank collected $' .. cashCollected .. ' from your cash for overdue loan',
                type = 'warning',
                duration = 10000
            })
        end
    end
end


function HandleFinalWarning(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 4 then return end
    
    local hugePenalty = math.ceil(loan.weekly_payment * 0.50)
    local newBalance = loan.remaining_balance + hugePenalty
    
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
- All cash and valuables seized
- Arrest warrant issued
- Jail time for debt evasion
- Permanent ban from future loans

Pay IMMEDIATELY to avoid legal action!

- %s
            ]], daysOverdue, hugePenalty, newBalance, Config.LetterSettings.Author)
        })
        
        TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
            title = '🚨 FINAL WARNING',
            description = 'Your loan is about to go to collections! Pay NOW!',
            type = 'error',
            duration = 15000
        })
    end
end


function HandleCollections(loan, daysOverdue)
    if overdueWarnings[loan.id] >= 5 then return end
    
    MySQL.update('UPDATE player_loans SET status = ? WHERE id = ?', {
        'collections',
        loan.id
    })
    
    overdueWarnings[loan.id] = 5
    
    local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
    if Player then
        local src = Player.PlayerData.source
        local cashSeized = 0
        
       
        if Config.LoanSettings.SeizeCashInCollections then
            cashSeized = Player.PlayerData.money.cash
            if cashSeized > 0 then
                Player.Functions.RemoveMoney('cash', cashSeized, "loan-collections-seizure")
                
                local newBalance = math.max(0, loan.remaining_balance - cashSeized)
                MySQL.update('UPDATE player_loans SET remaining_balance = ? WHERE id = ?', {
                    newBalance,
                    loan.id
                })
            end
        end
        
        
        if Config.LoanSettings.JailForCollections then
           
            TriggerServerEvent('rsg-lawman:server:lawmanAlert', 'unpaid loan!')
        end
        
        SendLoanLetter(src, {
            title = '🚨 SENT TO COLLECTIONS 🚨',
            content = string.format([[
COLLECTIONS NOTICE

Your loan has been sent to collections for non-payment after %d days.

ACTIONS TAKEN:
- All cash seized: $%d
- Account frozen
- Cannot apply for future loans
- Remaining balance: $%d

You MUST pay the remaining balance at a bank before you can conduct any business.

This is a serious offense and may result in arrest.

- Collections Agency
            ]], daysOverdue, cashSeized, math.max(0, loan.remaining_balance - cashSeized))
        })
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚨 LOAN IN COLLECTIONS',
            description = 'Your loan is in collections! All cash seized. Pay immediately!',
            type = 'error',
            duration = 20000
        })
    end
end

function SendPaymentReminders()
    local reminderDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.LetterSettings.ReminderDaysBefore * 24 * 60 * 60))
    
    MySQL.query('SELECT * FROM player_loans WHERE status = ? AND next_payment_due <= ? AND next_payment_due > NOW()', {
        'active',
        reminderDate
    }, function(upcomingLoans)
        if not upcomingLoans or #upcomingLoans == 0 then
            return
        end
        
        for _, loan in pairs(upcomingLoans) do
            local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
            
            if Player then
                
                local dueDate = loan.next_payment_due
                local formattedDate = "Soon"
                
                if type(dueDate) == "string" then
                    local year, month, day, hour, min = string.match(dueDate, "(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d)")
                    if year then
                        formattedDate = string.format("%s/%s/%s at %s:%s", day, month, year, hour, min)
                    end
                end
                
                SendLoanLetter(Player.PlayerData.source, {
                    title = 'Payment Reminder',
                    content = string.format([[
Payment Reminder

This is a friendly reminder that your loan payment is due soon.

Payment Amount: $%d
Due Date: %s
Remaining Balance: $%d
Payments Made: %d/%d

Please ensure you have sufficient cash available.

Late payments incur a 10%% penalty plus additional fees.

- %s
                    ]], loan.weekly_payment, formattedDate, loan.remaining_balance, loan.payments_made, loan.total_payments, Config.LetterSettings.Author)
                })
            end
        end
    end)
end

