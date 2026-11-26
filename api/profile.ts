declare const process: { env: Record<string,string|undefined> };

const escapeHtml=(value:string)=>value.replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]||char));

export default async function handler(req:any,res:any){
  const id=String(req.query?.id||'');
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)){
    res.status(400).send('Invalid MARKIO profile link');return;
  }
  const url=process.env.VITE_SUPABASE_URL;
  const key=process.env.VITE_SUPABASE_PUBLISHABLE_KEY;
  if(!url||!key){res.status(503).send('MARKIO profile previews are temporarily unavailable.');return;}
  try{
    const headers={apikey:key,Authorization:'Bearer '+key};
    const profileResponse=await fetch(url+'/rest/v1/profiles?select=id,display_name,username,photo_path,public_profile_enabled&id=eq.'+id+'&public_profile_enabled=eq.true&status=eq.active&limit=1',{headers});
    if(!profileResponse.ok)throw new Error('Profile lookup failed');
    const profiles=await profileResponse.json() as Array<{id:string;display_name:string;username:string;photo_path:string|null;public_profile_enabled:boolean}>;
    const profile=profiles[0];
    if(!profile){res.status(404).send('This MARKIO profile is private or unavailable.');return;}
    const storeResponse=await fetch(url+'/rest/v1/seller_profiles?select=user_id,store_name,description,cover_path,status&user_id=eq.'+id+'&status=eq.approved&limit=1',{headers});
    if(!storeResponse.ok)throw new Error('Store lookup failed');
    const stores=await storeResponse.json() as Array<{user_id:string;store_name:string;description:string;cover_path:string|null;status:string}>;
    const store=stores[0];
    if(!store){res.status(404).send('This MARKIO seller profile is unavailable.');return;}
    const name=escapeHtml(profile.display_name||store.store_name);
    const description=escapeHtml((store.description||'Student-owned business on MARKIO.').slice(0,180));
    const canonical='https://'+String(req.headers.host||'').replace(/[^a-zA-Z0-9.:-]/g,'')+'/u/'+id;
    const photo=profile.photo_path?url+'/storage/v1/object/public/bloom-profile-photos/'+profile.photo_path.split('/').map(encodeURIComponent).join('/'):store.cover_path?url+'/storage/v1/object/public/marketplace-images/'+store.cover_path.split('/').map(encodeURIComponent).join('/'):'';
    const image=escapeHtml(photo);
    const redirect='/?profile='+encodeURIComponent(id);
    res.setHeader('Content-Type','text/html; charset=utf-8');
    res.setHeader('Cache-Control','public, s-maxage=300, stale-while-revalidate=600');
    res.status(200).send('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+name+' · MARKIO</title><meta name="description" content="'+description+'"><link rel="canonical" href="'+canonical+'"><meta property="og:type" content="profile"><meta property="og:site_name" content="MARKIO"><meta property="og:title" content="'+name+' on MARKIO"><meta property="og:description" content="'+description+'"><meta property="og:url" content="'+canonical+'">'+(image?'<meta property="og:image" content="'+image+'"><meta name="twitter:card" content="summary_large_image">':'<meta name="twitter:card" content="summary">')+'<meta http-equiv="refresh" content="0;url='+redirect+'"></head><body><p>Opening '+name+' on MARKIO…</p><script>location.replace('+JSON.stringify(redirect)+')</script></body></html>');
  }catch(error){
    res.status(503).send('Unable to load this MARKIO profile preview right now.');
  }
}
