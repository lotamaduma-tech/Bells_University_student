import { useEffect, useState, type FormEvent, type ChangeEvent } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from './lib/supabase';
import { ArrowRight, ArrowLeft, Heart, Sparkles, ShieldCheck, Mail, LockKeyhole, Camera, Check, LoaderCircle, Flower2, LogOut } from 'lucide-react';
import App from './App';

type Stage = 'loading' | 'welcome' | 'auth' | 'confirm' | 'onboarding' | 'app';
type Intention = 'meaningful_relationship' | 'dating_with_intention' | 'open_to_relationship' | 'see_where_it_goes';
const intentions: {value:Intention;label:string}[] = [
  {value:'meaningful_relationship',label:'Campus community'},
  {value:'dating_with_intention',label:'Campus friends'},
  {value:'open_to_relationship',label:'Study / activity partners'},
  {value:'see_where_it_goes',label:'Meet new people'}
];
const splitList = (value:string, max:number) => [...new Set(value.split(',').map(v=>v.trim()).filter(Boolean))].slice(0,max);
const age16Date = () => { const d = new Date(); d.setFullYear(d.getFullYear()-16); return d.toISOString().slice(0,10); };

export default function AuthGate() {
  const [stage,setStage] = useState<Stage>('loading');
  const [session,setSession] = useState<Session|null>(null);
  const [authMode,setAuthMode] = useState<'signup'|'login'>('signup');
  const [email,setEmail] = useState('');
  const [password,setPassword] = useState('');
  const [displayName,setDisplayName] = useState('');
  const [dob,setDob] = useState('');
  const [bio,setBio] = useState('');
  const [interests,setInterests] = useState('');
  const [sports,setSports] = useState('');
  const [likes,setLikes] = useState('');
  const [dislikes,setDislikes] = useState('');
  const [intention,setIntention] = useState<Intention>('meaningful_relationship');
  const [photo,setPhoto] = useState<File|null>(null);
  const [photoPreview,setPhotoPreview] = useState('');
  const [busy,setBusy] = useState(false);
  const [error,setError] = useState('');
  const [notice,setNotice] = useState('');
  const [clientMissing,setClientMissing] = useState(!supabase);

  useEffect(() => {
    if (!supabase) { setStage('welcome'); return; }
    const client = supabase;
    let alive = true;
    const syncSession = async (next:Session|null) => {
      if (!alive) return;
      setSession(next);
      if (!next) { setStage('welcome'); return; }
      const {data,error:profileError} = await client.from('profiles').select('status,display_name').eq('id',next.user.id).maybeSingle();
      if (!alive) return;
      if (profileError) {
        setError('We could not load your BellsConnect profile. Confirm the database setup is complete.');
        setStage('onboarding');
      } else if (data?.status === 'active') {
        setDisplayName(data.display_name || next.user.user_metadata?.display_name || '');
        setStage('app');
      } else {
        setDisplayName(next.user.user_metadata?.display_name || '');
        setStage('onboarding');
      }
    };
    client.auth.getSession().then(({data}) => syncSession(data.session));
    const {data:{subscription}} = client.auth.onAuthStateChange((_event,next) => { void syncSession(next); });
    return () => { alive = false; subscription.unsubscribe(); };
  }, []);

  const updatePhoto = (event:ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0] || null;
    setError('');
    if (!file) { setPhoto(null); setPhotoPreview(''); return; }
    if (!['image/jpeg','image/png','image/webp'].includes(file.type)) { setError('Choose a JPG, PNG or WebP image.'); event.target.value=''; return; }
    if (file.size > 5*1024*1024) { setError('Your profile photo must be 5 MB or smaller.'); event.target.value=''; return; }
    setPhoto(file);
    setPhotoPreview(URL.createObjectURL(file));
  };

  const submitAuth = async (event:FormEvent) => {
    event.preventDefault(); setError(''); setNotice('');
    if (!supabase) { setError('Backend setup is not finished yet. BellsConnect needs the connected Supabase project and environment values.'); return; }
    if (password.length < 6) { setError('Use a password with at least 6 characters.'); return; }
    if (authMode==='signup') {
      if (!displayName.trim() || !dob) { setError('Enter your name and date of birth to continue.'); return; }
      if (dob > age16Date()) { setError('BellsConnect is for students aged 16 and above.'); return; }
    }
    setBusy(true);
    try {
      if (authMode==='signup') {
        const {data,error:signUpError} = await supabase.auth.signUp({
          email:email.trim().toLowerCase(), password,
          options:{data:{display_name:displayName.trim(),date_of_birth:dob}}
        });
        if (signUpError) throw signUpError;
        if (!data.session) {
          setNotice('Email confirmation is enabled in the Supabase project. Turn off Confirm email in Supabase Authentication settings to let new members enter without a verification link.');
          setStage('confirm');
        } else {
          setSession(data.session); setStage('onboarding');
        }
      } else {
        const {data,error:signInError} = await supabase.auth.signInWithPassword({email:email.trim().toLowerCase(),password});
        if (signInError) throw signInError;
        setSession(data.session);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'We could not complete that request. Try again.');
    } finally { setBusy(false); }
  };

  const finishProfile = async (event:FormEvent) => {
    event.preventDefault(); setError(''); setNotice('');
    if (!supabase || !session) { setError('Your session has expired. Please sign in again.'); return; }
    if (!photo) { setError('Add a profile photo to continue.'); return; }
    if (!displayName.trim() || displayName.trim().length<2) { setError('Your display name must be at least 2 characters.'); return; }
    setBusy(true);
    try {
      const extension = photo.type==='image/png'?'png':photo.type==='image/webp'?'webp':'jpg';
      const path = session.user.id+'/'+crypto.randomUUID()+'.'+extension;
      const {error:uploadError} = await supabase.storage.from('bloom-profile-photos').upload(path,photo,{contentType:photo.type,upsert:false});
      if (uploadError) throw uploadError;
      const {error:profileError} = await supabase.rpc('complete_profile',{
        display_name_value:displayName.trim(),
        bio_value:bio.trim(),
        photo_path_value:path,
        interests_value:splitList(interests,20),
        sports_value:splitList(sports,15),
        likes_value:splitList(likes,30),
        dislikes_value:splitList(dislikes,30),
        intention_value:intention
      });
      if (profileError) {
        await supabase.storage.from('bloom-profile-photos').remove([path]);
        throw profileError;
      }
      setStage('app');
      setNotice('');
    } catch(e) {
      setError(e instanceof Error ? e.message : 'We could not save your profile. Please try again.');
    } finally { setBusy(false); }
  };

  const signOut = async () => {
    if (!supabase) return;
    setBusy(true);
    await supabase.auth.signOut();
    setSession(null); setStage('welcome'); setAuthMode('login'); setPassword(''); setBusy(false);
  };

  if (stage==='loading') return <div className="bloom-loading"><span className="bloom-logo-mark"><Flower2/></span><strong>Bells<span>Connect</span></strong><LoaderCircle className="bloom-spinner"/></div>;
  if (stage==='app' && session) return <App displayName={displayName} onSignOut={signOut}/>;

  return <div className="bloom-auth-shell">
    <div className="bloom-auth-glow bloom-glow-one"/><div className="bloom-auth-glow bloom-glow-two"/>
    <header className="bloom-auth-header">
      <button className="bloom-wordmark" onClick={()=>{setStage('welcome');setError('')}}><span className="bloom-logo-mark"><Flower2 size={19}/></span>bloom<span>.</span></button>
      <span className="bloom-campus"><span/> BELLS UNIVERSITY</span>
    </header>
    <main className="bloom-auth-main">
      {stage==='welcome' && <section className="bloom-welcome">
        <div className="bloom-orbit-art" aria-hidden="true"><div className="bloom-orbit orbit-a"/><div className="bloom-orbit orbit-b"/><div className="bloom-heart"><Heart fill="currentColor" strokeWidth={1.2}/></div><span className="bloom-spark spark-a">✦</span><span className="bloom-spark spark-b">✧</span><span className="bloom-spark spark-c">✦</span><span className="bloom-art-caption">REAL PEOPLE. REAL CONNECTIONS.</span></div>
        <p className="bloom-eyebrow"><Sparkles size={14}/> YOUR CAMPUS, A LITTLE CLOSER</p>
        <h1>Your campus,<br/>your <em>people.</em></h1>
        <p className="bloom-welcome-copy">Meet real Bells students, find people who share your interests, plan a campus hangout, or find a study partner.</p>
        <div className="bloom-trust-row"><span><ShieldCheck size={16}/> Students aged 16+</span><span><LockKeyhole size={15}/> Privacy-minded</span></div>
        <button className="bloom-cta" onClick={()=>{setAuthMode('signup');setStage('auth');setError('')}}>Join BellsConnect <ArrowRight size={18}/></button>
        <button className="bloom-text-btn" onClick={()=>{setAuthMode('login');setStage('auth');setError('')}}>Already have an account? <strong>Log in</strong></button>
        <p className="bloom-fineprint">A campus community for real people and respectful connections.</p>
      </section>}
      {stage==='auth' && <section className="bloom-form-panel">
        <button className="bloom-back-link" onClick={()=>{setStage('welcome');setError('')}}><ArrowLeft size={16}/> Back</button>
        <p className="bloom-eyebrow"><Sparkles size={14}/> {authMode==='signup'?'YOUR NEXT CHAPTER':'WELCOME BACK'}</p>
        <h1>{authMode==='signup'?'Let’s get you blooming.':'Good to see you again.'}</h1>
        <p className="bloom-form-intro">{authMode==='signup'?'Create your account to start building a profile that feels like you.':'Log in to pick up where you left off.'}</p>
        <div className="bloom-mode-switch"><button className={authMode==='signup'?'active':''} onClick={()=>{setAuthMode('signup');setError('')}}>Create account</button><button className={authMode==='login'?'active':''} onClick={()=>{setAuthMode('login');setError('')}}>Log in</button></div>
        <form onSubmit={submitAuth} className="bloom-form">
          {authMode==='signup'&&<><label>Your name<input required autoComplete="name" value={displayName} onChange={e=>setDisplayName(e.target.value)} placeholder="What should we call you?" maxLength={50}/></label><label>Date of birth <small>BellsConnect is for students aged 16+</small><input required type="date" max={age16Date()} value={dob} onChange={e=>setDob(e.target.value)}/></label></>}
          <label>Email address<div className="bloom-input-wrap"><Mail size={17}/><input required type="email" autoComplete="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@example.com"/></div></label>
          <label>Password<div className="bloom-input-wrap"><LockKeyhole size={17}/><input required type="password" autoComplete={authMode==='signup'?'new-password':'current-password'} minLength={6} value={password} onChange={e=>setPassword(e.target.value)} placeholder="At least 6 characters"/></div></label>
          {error&&<p className="bloom-error" role="alert">{error}</p>}
          {clientMissing&&<p className="bloom-setup-note">Backend connection is pending. The form will work after the dedicated Supabase project and environment values are configured.</p>}
          <button className="bloom-cta" disabled={busy||clientMissing}>{busy?<LoaderCircle className="bloom-spinner"/>:authMode==='signup'?'Create my account':'Log in'} {!busy&&<ArrowRight size={17}/>}</button>
        </form>
        <p className="bloom-legal">By continuing, you agree to treat other members respectfully and use Bloom safely.</p>
      </section>}
      {stage==='confirm'&&<section className="bloom-form-panel bloom-confirm-panel"><div className="bloom-confirm-icon"><Mail size={26}/></div><p className="bloom-eyebrow">ONE QUICK CHECK</p><h1>Check your inbox.</h1><p className="bloom-form-intro">{notice||'Use the verification link we emailed you, then log in to finish your profile.'}</p><button className="bloom-cta" onClick={()=>{setStage('auth');setAuthMode('login');setPassword('');setError('')}}>Back to log in <ArrowRight size={17}/></button><button className="bloom-text-btn" onClick={()=>{setStage('welcome');setNotice('')}}>Return home</button></section>}
      {stage==='onboarding'&&<section className="bloom-form-panel bloom-onboarding-panel">
        <div className="bloom-progress"><span/><span/><span/></div><p className="bloom-eyebrow"><Sparkles size={14}/> YOUR PROFILE, YOUR WAY</p><h1>Let’s make it <em>you.</em></h1><p className="bloom-form-intro">A few details help people discover what you have in common. Keep it honest and comfortable.</p>
        <form className="bloom-form" onSubmit={finishProfile}>
          <label className="bloom-photo-upload"><input type="file" accept="image/jpeg,image/png,image/webp" onChange={updatePhoto}/>{photoPreview?<img src={photoPreview} alt="Profile preview"/>:<span className="bloom-photo-placeholder"><Camera size={25}/><strong>Add your profile photo</strong><small>JPG, PNG or WebP · up to 5 MB</small></span>}<span className="bloom-photo-edit"><Camera size={15}/></span></label>
          <label>Display name<input required value={displayName} onChange={e=>setDisplayName(e.target.value)} maxLength={50} placeholder="Your name"/></label>
          <label>A little about you<textarea value={bio} onChange={e=>setBio(e.target.value)} maxLength={500} placeholder="What would you want someone to know about you?"/></label>
          <label>Things you enjoy <small>Separate each with a comma</small><input value={interests} onChange={e=>setInterests(e.target.value)} placeholder="Music, reading, coding, cooking"/></label>
          <label>Sports you’re into <small>Optional · comma-separated</small><input value={sports} onChange={e=>setSports(e.target.value)} placeholder="Football, basketball, tennis"/></label>
          <label>Things you like <small>Optional · comma-separated</small><input value={likes} onChange={e=>setLikes(e.target.value)} placeholder="Honesty, outdoor dates, Afrobeats"/></label>
          <label>Things you don’t like <small>Optional · comma-separated</small><input value={dislikes} onChange={e=>setDislikes(e.target.value)} placeholder="Rudeness, ghosting, loud places"/></label>
          <label>What would you like to do on campus?<select value={intention} onChange={e=>setIntention(e.target.value as Intention)}>{intentions.map(i=><option value={i.value} key={i.value}>{i.label}</option>)}</select></label>
          {error&&<p className="bloom-error" role="alert">{error}</p>}
          <button className="bloom-cta" disabled={busy}>{busy?<><LoaderCircle className="bloom-spinner"/> Saving your profile…</>:<>Finish profile <Check size={17}/></>}</button>
          <p className="bloom-legal">Your date of birth stays private. Your profile photo is stored in a private bucket. You can review and change profile details later.</p>
        </form>
      </section>}
    </main>
    <footer className="bloom-auth-footer"><span>© {new Date().getFullYear()} BellsConnect</span><span><ShieldCheck size={14}/> Built for thoughtful connections</span></footer>
  </div>;
}
