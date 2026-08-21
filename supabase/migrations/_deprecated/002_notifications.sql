-- Create notifications table for dynamic notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('cancellation', 'holiday', 'completed', 'reminder', 'info', 'alert')),
    audience TEXT NOT NULL CHECK (audience IN ('resident', 'manager', 'admin', 'all')),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_audience ON notifications(audience);
CREATE INDEX IF NOT EXISTS idx_notifications_property_id ON notifications(property_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_active ON notifications(is_active);

-- Row Level Security Policies
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see notifications meant for their audience or their property
CREATE POLICY "Users can view notifications for their audience or property" ON notifications
    FOR SELECT USING (
        -- Authenticated users can see notifications
        auth.role() = 'authenticated' AND (
            -- Global notifications (no property_id)
            (property_id IS NULL AND audience IN ('resident', 'all')) OR
            -- Property-specific notifications
            (property_id IN (
                SELECT property_id FROM user_properties 
                WHERE user_id = auth.uid()
            )) OR
            -- Manager/admin notifications
            audience IN ('manager', 'admin', 'all')
        )
    );

-- Policy: Managers and admins can create notifications
CREATE POLICY "Managers and admins can create notifications" ON notifications
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND (
            -- Only managers and admins can create notifications
            EXISTS (
                SELECT 1 FROM user_properties 
                WHERE user_id = auth.uid() 
                AND role IN ('manager', 'admin')
            )
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
