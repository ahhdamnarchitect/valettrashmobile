-- 027 - storage: let the owner tier and ops managers upload evidence photos.
--
-- 006's worker upload policy tested role IN ('driver','property_manager','super_admin').
-- After 013 made `owner` the canonical business-owner role, and with
-- operations_manager doing field work, both were locked out of the workers/ prefix.
-- Same gap 020 fixed for the tables.
--
-- Path scheme is unchanged and is what the app now writes (see
-- lib/core/storage/photo_storage.dart):
--     users/<uid>/...    residents
--     workers/<uid>/...  driver, property_manager, operations_manager, owner, super_admin

DROP POLICY IF EXISTS "Workers upload violation photos" ON storage.objects;
CREATE POLICY "Workers upload violation photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'workers'
    AND (storage.foldername(name))[2] = auth.uid()::text
    AND EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND role IN ('driver', 'property_manager', 'operations_manager', 'owner', 'super_admin')
    )
);

-- Owner tier needs to review any evidence photo, not just its own uploads.
DROP POLICY IF EXISTS "Owner admins read all violation files" ON storage.objects;
CREATE POLICY "Owner admins read all violation files"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'violations' AND private.is_owner_admin());
