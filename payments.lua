local RSGCore = exports['rsg-core']:GetCoreObject()

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
            -- Apply late fee
            local lateFee = math.ceil(loan.weekly_payment * (Config.LoanSettings.LatePaymentPenalty / 100))
            local newBalance = loan.remaining_balance + lateFee
            
            MySQL.update('UPDATE player_loans SET remaining_balance = ? WHERE id = ?', {
                newBalance,
                loan.id
            })

            -- Send warning letter to player
            local Player = RSGCore.Functions.GetPlayerByCitizenId(loan.citizenid)
            if Player then
                SendLoanLetter(Player.PlayerData.source, {
                    title = 'OVERDUE PAYMENT NOTICE',
                    content = string.format([[
URGENT: Payment Overdue

Your loan payment was due on %s and has not been received.

A late fee of $%d has been added to your balance.

Current Balance: $%d
Please make a payment immediately to avoid further penalties.

- %s
                    ]], loan.next_payment_due, lateFee, newBalance, Config.LetterSettings.Author)
                })
            end
        end
    end)
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