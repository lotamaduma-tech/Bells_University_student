import { useCallback, useEffect, useState } from 'react';
import { ArrowLeft, LockKeyhole, LoaderCircle, LogOut, RefreshCw, ShieldCheck } from 'lucide-react';
import { supabase } from './lib/supabase';

type Feedback = { id:string; user_id:string|null; category:string; message:string; status:'new'|'reviewing'|'resolved'; admin_notes:string|null; created_at:string };
type SafetyReport = { id:string; reporter_id:string; reported_id:string; reason:string; details:string; status:'open'|'reviewing'|'resolved'|'dismissed'; created_at:string };
const stamp = (value:string) => new Date(value).toLocaleString([], { dateStyle:'medium', timeStyle:'short' });

export default function AdminDashboard() {
  const [loading,setLoading] = useState(true);
  const [allowed,setAllowed] = useState(false);
  const [rows,setRows] = useState<Feedback[]>([]);
  const [safetyReports,setSafetyReports] = useState<SafetyReport[]>([]);
  const [safetyFilter,setSafetyFilter] = useState('open');
  const [filter,setFilter] = useState('all');
  const [error,setError] = useState('');
  const [email,setEmail] = useState('');

  const load = useCallback(async () => {
    if (!supabase) { setError('Supabase is not configured.'); setLoading(false); return; }
    setLoading(true); setError('');
    try {
      const {data:{user},error:userError} = await supabase.auth.getUser();
      if (userError) throw userError;
      if (!user) { setAllowed(false); setError('Sign in to BellsConnect first, then open this page again.'); return; }
      setEmail(user.email || '');
      const {data:membership,error:membershipError} = await supabase.from('bellsconnect_admins').select('user_id').eq('user_id',user.id).maybeSingle();
      if (membershipError) throw membershipError;
      if (!membership) { setAllowed(false); setError('This account is not an authorized BellsConnect administrator yet.'); return; }
      setAllowed(true);
      const {data,error:rowsError} = await supabase.from('bellsconnect_feedback').select('id,user_id,category,message,status,admin_notes,created_at').order('created_at',{ascending:false}).limit(500);
      if (rowsError) throw rowsError;
      setRows((data || []) as Feedback[]);
      const {data:safetyData,error:safetyError} = await supabase.from('campus_user_reports').select('id,reporter_id,reported_id,reason,details,status,created_at').order('created_at',{ascending:false}).limit(500);
      if (safetyError) throw safetyError;
      setSafetyReports((safetyData || []) as SafetyReport[]);
    } catch (e) { setError(e instanceof Error ? e.message : 'Could not load feedback.'); }
    finally { setLoading(false); }
  },[]);

  useEffect(()=>{ void load(); },[load]);

  const updateStatus = async (id:string,status:Feedback['status']) => {
    if (!supabase) return;
    const {error:e} = await supabase.from('bellsconnect_feedback').update({status}).eq('id',id);
    if (e) { setError(e.message); return; }
    setRows(old=>old.map(r=>r.id===id?{...r,status}:r));
  };
  const updateSafetyStatus = async (id:string,status:SafetyReport['status']) => { if (!supabase) return; const {error:e}=await supabase.from('campus_user_reports').update({status}).eq('id',id); if(e){setError(e.message);return;} setSafetyReports(old=>old.map(r=>r.id===id?{...r,status}:r)); };
  const signOut = async () => { if(supabase) await supabase.auth.signOut(); window.location.href='/'; };

  const visible = rows.filter(r=>filter==='all'||r.status===filter);
  const visibleSafetyReports = safetyReports.filter(r=>safetyFilter==='all'||r.status===safetyFilter);
  return <main className="bc-admin-shell">
    <style>{`.bc-admin-shell{min-height:100vh;background:#f6f8f6;color:#202b25;padding:clamp(18px,4vw,48px);font-family:Inter,system-ui,sans-serif}.bc-admin-wrap{max-width:1000px;margin:auto}.bc-admin-head{display:flex;align-items:center;justify-content:space-between;gap:14px;flex-wrap:wrap;margin-bottom:28px}.bc-admin-brand{display:flex;align-items:center;gap:12px}.bc-admin-brand>span{display:grid;place-items:center;width:45px;height:45px;background:#e2f4e9;color:#24734f;border-radius:14px}.bc-admin-head h1{font-size:clamp(24px,4vw,34px);margin:0}.bc-admin-head p,.bc-admin-muted{color:#69756e;font-size:13px;line-height:1.6}.bc-admin-btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;border:1px solid #dce5df;border-radius:11px;padding:10px 13px;background:white;color:#314239;cursor:pointer;text-decoration:none;font:600 12px inherit}.bc-admin-stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin:20px 0}.bc-admin-stat,.bc-admin-card{background:white;border:1px solid #e2e9e4;border-radius:17px;padding:17px}.bc-admin-stat small{color:#748078;font-size:12px}.bc-admin-stat strong{display:block;font-size:28px;margin-top:7px}.bc-admin-list{display:grid;gap:12px}.bc-admin-card-top{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;flex-wrap:wrap}.bc-admin-pill{font-size:11px;text-transform:capitalize;padding:6px 9px;border-radius:99px;background:#edf5ef;color:#326c4d}.bc-admin-card h3{font-size:14px;text-transform:capitalize;margin:0}.bc-admin-message{white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px;line-height:1.7;margin:14px 0}.bc-admin-meta{font-size:11px;color:#748078}.bc-admin-tools{display:flex;gap:8px;flex-wrap:wrap;align-items:center}.bc-admin-tools select{border:1px solid #dce5df;border-radius:10px;padding:10px;background:white;color:#34463a}.bc-admin-error{padding:13px;border-radius:12px;background:#fff0f0;color:#9f3030;margin:14px 0;font-size:13px}.bc-admin-empty{padding:42px;text-align:center;border:1px dashed #cfdad2;border-radius:16px;color:#6b776f;background:#fff}.bc-admin-login{max-width:560px;margin:10vh auto;background:#fff;border:1px solid #e1e8e3;border-radius:20px;padding:28px}.bc-admin-login h2{margin:12px 0}.bc-admin-login code{overflow-wrap:anywhere}@media(max-width:560px){.bc-admin-stats{grid-template-columns:1fr}.bc-admin-stat{padding:14px}.bc-admin-stat strong{font-size:23px}}`}</style>
    <div className="bc-admin-wrap">
      <header className="bc-admin-head"><div className="bc-admin-brand"><span><ShieldCheck size={24}/></span><div><h1>BellsConnect feedback</h1><p>Private developer dashboard · {email || 'Administrator access'}</p></div></div><div className="bc-admin-tools"><button className="bc-admin-btn" onClick={()=>void load()}><RefreshCw size={15}/> Refresh</button><button className="bc-admin-btn" onClick={()=>void signOut()}><LogOut size={15}/> Sign out</button></div></header>
      {error && <div className="bc-admin-error">{error}{!allowed&&<p>To grant your account access, use Supabase SQL Editor and follow the setup instructions in the repository README / completion notes.</p>}</div>}
      {loading ? <div className="bc-admin-empty"><LoaderCircle size={22}/> Loading private feedback…</div> : allowed && <>
        <section className="bc-admin-stats"><div className="bc-admin-stat"><small>Total submissions</small><strong>{rows.length}</strong></div><div className="bc-admin-stat"><small>New</small><strong>{rows.filter(r=>r.status==='new').length}</strong></div><div className="bc-admin-stat"><small>Resolved</small><strong>{rows.filter(r=>r.status==='resolved').length}</strong></div></section>
        <div className="bc-admin-tools" style={{marginBottom:16}}><label className="bc-admin-muted" htmlFor="bc-admin-filter">Show:</label><select id="bc-admin-filter" value={filter} onChange={e=>setFilter(e.target.value)}><option value="all">All feedback</option><option value="new">New</option><option value="reviewing">Reviewing</option><option value="resolved">Resolved</option></select><span className="bc-admin-muted">{visible.length} shown</span></div>
        <section className="bc-admin-list">{visible.length ? visible.map(r=><article className="bc-admin-card" key={r.id}><div className="bc-admin-card-top"><div><h3>{r.category.replace('_',' ')}</h3><p className="bc-admin-meta">{stamp(r.created_at)} · User ID: {r.user_id || 'not available'}</p></div><span className="bc-admin-pill">{r.status}</span></div><p className="bc-admin-message">{r.message}</p><div className="bc-admin-tools"><label className="bc-admin-muted" htmlFor={'status-'+r.id}>Status:</label><select id={'status-'+r.id} value={r.status} onChange={e=>void updateStatus(r.id,e.target.value as Feedback['status'])}><option value="new">New</option><option value="reviewing">Reviewing</option><option value="resolved">Resolved</option></select></div></article>) : <div className="bc-admin-empty">No feedback matches this filter yet.</div>}</section>
        <section style={{marginTop:32}}>
          <header className="bc-admin-head"><div><h2 style={{margin:0,fontSize:22}}>Student safety reports</h2><p>Private reports submitted by members.</p></div><div className="bc-admin-tools"><label className="bc-admin-muted" htmlFor="bc-safety-filter">Show:</label><select id="bc-safety-filter" value={safetyFilter} onChange={e=>setSafetyFilter(e.target.value)}><option value="open">Open</option><option value="reviewing">Reviewing</option><option value="resolved">Resolved</option><option value="dismissed">Dismissed</option><option value="all">All reports</option></select></div></header>
          <section className="bc-admin-list">{visibleSafetyReports.length?visibleSafetyReports.map(r=><article className="bc-admin-card" key={r.id}><div className="bc-admin-card-top"><div><h3>{r.reason}</h3><p className="bc-admin-meta">{stamp(r.created_at)} · Reporter {r.reporter_id} · Reported account {r.reported_id}</p></div><span className="bc-admin-pill">{r.status}</span></div><p className="bc-admin-message">{r.details||'No additional details provided.'}</p><div className="bc-admin-tools"><label className="bc-admin-muted" htmlFor={'safety-status-'+r.id}>Status:</label><select id={'safety-status-'+r.id} value={r.status} onChange={e=>void updateSafetyStatus(r.id,e.target.value as SafetyReport['status'])}><option value="open">Open</option><option value="reviewing">Reviewing</option><option value="resolved">Resolved</option><option value="dismissed">Dismissed</option></select></div></article>):<div className="bc-admin-empty">No safety reports in this filter.</div>}</section>
        </section>
      </>}
      {!loading&&!allowed&&<section className="bc-admin-login"><LockKeyhole size={28}/><h2>Private administrator access</h2><p className="bc-admin-muted">Only accounts listed in the <code>public.bellsconnect_admins</code> table can view feedback. Sign in with your intended BellsConnect admin account, then add its user UUID to that table using the Supabase SQL Editor.</p><a className="bc-admin-btn" href="https://supabase.com/dashboard/project/gxiirebjidkgucucegzn/auth/users" target="_blank" rel="noreferrer">Open Supabase users</a></section>}
      <p className="bc-admin-muted" style={{marginTop:28}}>Feedback content is private. Keep this page and your admin account secure.</p>
    </div>
  </main>;
}
