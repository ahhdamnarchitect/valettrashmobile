-- Enhanced notifications table for complex targeting
-- This migration adds user_id for direct notifications and updates RLS policies

-- Add user_id column for direct user targeting
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Add index for user_id queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- Update RLS policies for complex targeting
DROP POLICY IF EXISTS "Users can view notifications for their audience or property" ON notifications;
DROP POLICY IF EXISTS "Managers and admins can create notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;

-- New Policy: Users can see notifications sent directly to them OR property-wide notifications
CREATE POLICY "Users can view direct or property notifications" ON notifications
    FOR SELECT USING (
        -- Authenticated users only
        auth.role() = 'authenticated' AND (
            -- Direct notifications sent to this user
            user_id = auth.uid() OR
            -- Property-wide notifications for user's properties
            (property_id IN (
                SELECT property_id FROM user_properties 
                WHERE user_id = auth.uid()
            ) AND user_id IS NULL) OR
            -- Global notifications (no property_id, no user_id)
            (property_id IS NULL AND user_id IS NULL AND audience IN ('resident', 'all'))
        )
    );

-- New Policy: Managers and admins can create notifications with complex targeting
CREATE POLICY "Managers and admins can create notifications" ON notifications
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND (
            -- Only managers and admins can create notifications
            EXISTS (
                SELECT 1 FROM user_properties 
                WHERE user_id = auth.uid() 
                AND role IN ('manager', 'admin')
            )
        ) AND (
            -- Must target either specific user, specific property, or be global
            (user_id IS NOT NULL) OR 
            (property_id IS NOT NULL) OR 
            (user_id IS NULL AND property_id IS NULL)
        )
    );

-- Policy: Notification creators can update their own notifications
CREATE POLICY "Users can update their own notifications" ON notifications
    FOR UPDATE USING (
        auth.role() = 'authenticated' AND 
        sender_id = auth.uid()
    );

-- Policy: Notification creators can delete their own notifications
CREATE POLICY "Users can delete their own notifications" ON notifications
    FOR DELETE USING (
        auth.role() = 'authenticated' AND 
        sender_id = auth.uid()
    );
