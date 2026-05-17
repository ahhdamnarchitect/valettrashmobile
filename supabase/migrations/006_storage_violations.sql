-- Storage bucket for violation / support photos (private; access via RLS policies)

DROP POLICY IF EXISTS "Users upload own violation files" ON storage.objects;
DROP POLICY IF EXISTS "Users read own violation files" ON storage.objects;
DROP POLICY IF EXISTS "Users update own violation files" ON storage.objects;
DROP POLICY IF EXISTS "Workers upload violation photos" ON storage.objects;
DROP POLICY IF EXISTS "Workers read own uploads" ON storage.objects;

INSERT INTO storage.buckets (id, name, public)
VALUES ('violations', 'violations', false)
ON CONFLICT (id) DO NOTHING;

-- Residents: read/write own folder users/<uid>/...
CREATE POLICY "Users upload own violation files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'users'
    AND (storage.foldername(name))[2] = auth.uid()::text
);

CREATE POLICY "Users read own violation files"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'users'
    AND (storage.foldername(name))[2] = auth.uid()::text
);

CREATE POLICY "Users update own violation files"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'users'
    AND (storage.foldername(name))[2] = auth.uid()::text
);

-- Drivers can use workers/<uid>/...
CREATE POLICY "Workers upload violation photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'workers'
    AND (storage.foldername(name))[2] = auth.uid()::text
    AND EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('driver', 'property_manager', 'super_admin')
    )
);

CREATE POLICY "Workers read own uploads"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'workers'
    AND (storage.foldername(name))[2] = auth.uid()::text
);
