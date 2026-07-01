#!/bin/bash
# One-Click Deploy für Premium Subscription System
# Führe dieses Script aus ODER kopiere die SQL manuell

echo "🚀 Premium Subscription System - Deployment"
echo "=========================================="
echo ""
echo "📋 Du musst die SQL manuell in Supabase ausführen:"
echo ""
echo "1. Öffne: https://supabase.com/dashboard/project/rtwzzerhgieyxsijemsd/sql/new"
echo ""
echo "2. Kopiere den KOMPLETTEN Inhalt von:"
echo "   database/migrations/premium_subscription_system.sql"
echo ""
echo "3. Füge ihn im SQL Editor ein"
echo ""
echo "4. Klicke auf 'Run' (grüner Button)"
echo ""
echo "5. Warte auf Success-Message"
echo ""
echo "=========================================="
echo ""
echo "💡 Quick Copy:"
echo ""

# Öffne die Datei im Standard-Editor
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open -a "TextEdit" database/migrations/premium_subscription_system.sql
    open "https://supabase.com/dashboard/project/rtwzzerhgieyxsijemsd/sql/new"
    echo "✅ SQL-Datei und Supabase geöffnet!"
    echo ""
    echo "➡️  Kopiere aus TextEdit → Paste in Supabase → Run"
else
    echo "📄 Öffne: database/migrations/premium_subscription_system.sql"
    echo "🌐 Öffne: https://supabase.com/dashboard/project/rtwzzerhgieyxsijemsd/sql/new"
fi

echo ""
echo "=========================================="
echo "✅ Nach dem Deployment, verify mit:"
echo ""
echo "SELECT routine_name FROM information_schema.routines"
echo "WHERE routine_name IN ('activate_subscription', 'activate_trial', 'is_premium_user');"
echo ""
echo "Erwartetes Ergebnis: 3 Zeilen"
echo "=========================================="
