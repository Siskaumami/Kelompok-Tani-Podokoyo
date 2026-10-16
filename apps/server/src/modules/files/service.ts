import { randomUUID } from 'node:crypto';
import { S3Client,PutObjectCommand,GetObjectCommand,DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { fileTypeFromBuffer } from 'file-type';
import sharp from 'sharp';
import { sql } from 'drizzle-orm';
import type { Db } from '../../core/database.js';
import { config,integrationStatus } from '../../core/config.js';
import { AppError,requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import type { Actor } from '../../../../../packages/shared/src/schemas.js';

function client(){if(!integrationStatus().storage)throw new AppError(503,'STORAGE_NOT_CONFIGURED','Penyimpanan gambar belum dikonfigurasi.');return new S3Client({region:'auto',endpoint:'https://s3.filebase.io',credentials:{accessKeyId:config.FILEBASE_ACCESS_KEY_ID,secretAccessKey:config.FILEBASE_SECRET_ACCESS_KEY},requestHandler:{requestTimeout:10000,connectionTimeout:5000}});}

export async function prepareImage(buffer:Buffer){if(buffer.length>5*1024*1024)throw new AppError(413,'FILE_TOO_LARGE','Ukuran gambar maksimal 5 MB.');const type=await fileTypeFromBuffer(buffer);if(!type||!['image/jpeg','image/png','image/webp'].includes(type.mime))throw new AppError(422,'FILE_TYPE','Gunakan gambar JPEG, PNG atau WebP.');try{return await sharp(buffer,{limitInputPixels:25_000_000,animated:false}).rotate().resize({width:1800,height:1800,fit:'inside',withoutEnlargement:true}).webp({quality:85}).toBuffer();}catch{throw new AppError(422,'INVALID_IMAGE','Gambar tidak dapat dibaca atau ukurannya terlalu besar.');}}

export async function uploadImage(tx:Db,a:Actor,buffer:Buffer){const storage=client(),objectKey=`${a.org_id}/images/${randomUUID()}.webp`;try{await storage.send(new PutObjectCommand({Bucket:config.FILEBASE_BUCKET,Key:objectKey,Body:buffer,ContentType:'image/webp',ContentDisposition:'inline'}));}catch(error){console.error('Filebase upload failed:',error);throw new AppError(502,'STORAGE_FAILED','Gambar belum berhasil disimpan oleh penyedia penyimpanan.');}try{const [f]=await tx.all(sql`INSERT INTO file_objects(org_id,object_key,mime,size_bytes,uploaded_by) VALUES(${a.org_id},${objectKey},'image/webp',${buffer.length},${a.id}) RETURNING id,mime,size_bytes,created_at`);await audit(tx,a,'IMAGE_UPLOADED','FILE',f.id,null,f);return f;}catch(error){try{await storage.send(new DeleteObjectCommand({Bucket:config.FILEBASE_BUCKET,Key:objectKey}));}catch{console.error(JSON.stringify({event:'orphan_image_cleanup_failed',org_id:a.org_id}));}throw error;}}

export async function signedImage(db:Db,org:string,id:string){const f=requireValue((await db.all(sql`SELECT object_key FROM file_objects WHERE org_id=${org} AND id=${id}`))[0]);try{return await getSignedUrl(client(),new GetObjectCommand({Bucket:config.FILEBASE_BUCKET,Key:f.object_key,ResponseContentType:'image/webp',ResponseContentDisposition:'inline'}),{expiresIn:300});}catch(e){if(e instanceof AppError)throw e;throw new AppError(502,'STORAGE_FAILED','Gambar sementara tidak dapat diakses.');}}

export async function publicImage(db:Db,slug:string,id:string){const org=requireValue((await db.all(sql`SELECT o.id FROM organizations o WHERE o.slug=${slug} AND ((o.publication='PUBLISHED' AND o.village_image_id=${id}) OR EXISTS(SELECT 1 FROM products p WHERE p.org_id=o.id AND p.image_id=${id} AND p.publication='PUBLISHED' AND NOT p.archived) OR EXISTS(SELECT 1 FROM farmers f WHERE f.org_id=o.id AND f.image_id=${id} AND f.publication='PUBLISHED' AND NOT f.archived))`))[0]);return signedImage(db,org.id,id);}