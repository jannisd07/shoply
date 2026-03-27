import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
    try {
        // Call the database function to expire subscriptions
        const { data, error } = await supabase.rpc('expire_subscriptions')

        if (error) {
            console.error('Error expiring subscriptions:', error)
            return new Response(JSON.stringify({
                error: error.message,
                success: false
            }), {
                status: 500,
                headers: { 'Content-Type': 'application/json' }
            })
        }

        console.log('Successfully expired subscriptions')
        return new Response(JSON.stringify({
            success: true,
            message: 'Subscriptions expired successfully'
        }), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
        })

    } catch (err) {
        console.error('Unexpected error:', err)
        return new Response(JSON.stringify({
            error: 'Internal server error',
            success: false
        }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
        })
    }
})