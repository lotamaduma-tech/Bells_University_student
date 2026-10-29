import { supabase } from './supabase';

export type BloomProfile = {
  id:string; display_name:string; date_of_birth:string; bio:string; photo_path:string|null;
  interests:string[]; sports:string[]; likes:string[]; dislikes:string[];
  relationship_intention:string|null; affiliation_status:string; status:string;
  age:number; photo_url:string|null;
};
export type BloomMessage = { id:string; conversation_id:string; sender_id:string; body:string; created_at:string; edited_at:string|null; deleted_at:string|null };

function requireClient() {
  if (!supabase) throw new Error('Bloom backend is not configured. Add VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY.');
  return supabase;
}
function ageFromDob(value:string) {
  const dob=new Date(value+'T00:00:00');
  const now=new Date();
  return now.getFullYear()-dob.getFullYear()-((now.getMonth()<dob.getMonth()||(now.getMonth()===dob.getMonth()&&now.getDate()<dob.getDate()))?1:0);
}

export async function getCurrentUserId() {
  const client=requireClient();
  const {data,error}=await client.auth.getUser();
  if(error) throw error;
  if(!data.user) throw new Error('Please sign in again.');
  return data.user.id;
}

export async function getDiscoveryProfiles(excludeIds:string[] = []):Promise<BloomProfile[]> {
  const client=requireClient();
  const userId=await getCurrentUserId();
  const {data,error}=await client.from('profiles')
    .select('id,display_name,date_of_birth,bio,photo_path,interests,sports,likes,dislikes,relationship_intention,affiliation_status,status')
    .eq('status','active').neq('id',userId).order('created_at',{ascending:false}).limit(40);
  if(error) throw error;
  const excluded=new Set(excludeIds);
  const visible=(data||[]).filter(p=>!excluded.has(p.id));
  return Promise.all(visible.map(async p=>{
    let photo_url:string|null=null;
    if(p.photo_path){
      const {data:signed,error:signError}=await client.storage.from('bloom-profile-photos').createSignedUrl(p.photo_path,60*30);
      if(!signError) photo_url=signed.signedUrl;
    }
    return {...p,age:ageFromDob(p.date_of_birth),photo_url} as BloomProfile;
  }));
}

export async function recordDecision(targetId:string,decision:'like'|'pass') {
  const client=requireClient();
  const {data,error}=await client.rpc('record_like',{target_user:targetId,decision_value:decision});
  if(error) throw error;
  return data as {matched:boolean;match_id?:string;conversation_id?:string};
}

export async function listConversationMessages(conversationId:string):Promise<BloomMessage[]> {
  const client=requireClient();
  const {data,error}=await client.from('messages')
    .select('id,conversation_id,sender_id,body,created_at,edited_at,deleted_at')
    .eq('conversation_id',conversationId).is('deleted_at',null)
    .order('created_at',{ascending:true}).limit(500);
  if(error) throw error;
  return (data||[]) as BloomMessage[];
}

export async function sendConversationMessage(conversationId:string,body:string):Promise<BloomMessage> {
  const client=requireClient();
  const userId=await getCurrentUserId();
  const clean=body.trim();
  if(!clean||clean.length>3000) throw new Error('Messages must contain 1–3000 characters.');
  const {data,error}=await client.from('messages')
    .insert({conversation_id:conversationId,sender_id:userId,body:clean})
    .select('id,conversation_id,sender_id,body,created_at,edited_at,deleted_at').single();
  if(error) throw error;
  return data as BloomMessage;
}

export function subscribeToConversationMessages(
  conversationId:string,
  onMessage:(message:BloomMessage)=>void,
  onError?:(message:string)=>void
) {
  const client=requireClient();
  const channel=client.channel('bloom-messages-'+conversationId)
    .on('postgres_changes',{
      event:'INSERT',schema:'public',table:'messages',filter:'conversation_id=eq.'+conversationId
    },payload=>onMessage(payload.new as BloomMessage))
    .subscribe(status=>{
      if(status==='CHANNEL_ERROR'||status==='TIMED_OUT') onError?.('Realtime connection interrupted. Check your connection and reopen the chat if updates stop.');
    });
  return ()=>{ void client.removeChannel(channel); };
}

export async function blockMember(blockedId:string) {
  const client=requireClient();
  const blockerId=await getCurrentUserId();
  const {error}=await client.from('blocks').upsert({blocker_id:blockerId,blocked_id:blockedId},{onConflict:'blocker_id,blocked_id'});
  if(error) throw error;
}

export async function reportMember(input:{reportedUserId?:string;messageId?:string;reason:string;details?:string}) {
  const client=requireClient();
  const reporterId=await getCurrentUserId();
  const {error}=await client.from('reports').insert({
    reporter_id:reporterId,reported_user_id:input.reportedUserId||null,
    message_id:input.messageId||null,reason:input.reason.trim(),details:(input.details||'').trim()
  });
  if(error) throw error;
}
