// Vercel serverless function: reads a poster image with Claude and returns the record info as JSON.
// The API key stays here on the server (set ANTHROPIC_API_KEY in Vercel → Settings → Environment Variables).
function posterPrompt(){
  const y=new Date().getFullYear();
  return `이 이미지는 공연·전시·페스티벌 포스터예요. 포스터에 적힌 내용을 읽고 아래 모양의 JSON 하나로만 답하세요. 포스터에 없는 정보는 지어내지 말고 빈 문자열로 두세요.
{"kind":"festival 또는 ticket","category":"페스티벌|전시|콘서트|뮤지컬|연극|클래식 중 하나","title":"포스터에 적힌 공식 공연명 전체(줄이지 말 것)","cutout":"공연명 전체를 한 글자도 빼지 말고 /로 줄을 나눠 적기. 한 줄 2~5글자, 줄 수 제한 없음 (예: PENTA/PORT, 서울/재즈/페스티벌)","flag":"깃발에 쓸 영문 대문자 2~3단어 (예: ROCK FESTIVAL, JAZZ NIGHT, EXHIBITION)","date":"YYYY-MM-DD 시작일","time":"HH:MM 또는 빈칸","place":"장소 이름 짧게(16자 이내)","cast":"주요 출연진 짧게(20자 이내)","days":["팔찌에 쓸 날짜별 짧은 영문 문구 최대 3개, 예: DAY1 8.2"],"vibe":"rock|chill|cute|cheer 중 하나"}
여러 날 열리는 음악·야외 페스티벌이면 kind는 festival, 그 밖의 전시·콘서트·뮤지컬·연극·클래식은 ticket이에요. 연도가 안 보이면 ${y}년으로 보세요.`;
}

const MODEL=process.env.ANTHROPIC_MODEL||'claude-sonnet-5-5';

export default async function handler(req,res){
  if(req.method!=='POST')return res.status(405).json({code:'method_not_allowed'});
  const key=process.env.ANTHROPIC_API_KEY;
  if(!key)return res.status(500).json({code:'no_api_key'});
  const image=req.body&&req.body.image;
  const m=typeof image==='string'&&image.match(/^data:(image\/(?:jpeg|png|webp));base64,(.+)$/);
  if(!m)return res.status(400).json({code:'image_rejected'});
  if(m[2].length>4_000_000)return res.status(413).json({code:'image_rejected'});
  try{
    const r=await fetch('https://api.anthropic.com/v1/messages',{method:'POST',
      headers:{'content-type':'application/json','x-api-key':key,'anthropic-version':'2023-06-01'},
      body:JSON.stringify({model:MODEL,max_tokens:800,messages:[{role:'user',content:[
        {type:'image',source:{type:'base64',media_type:m[1],data:m[2]}},
        {type:'text',text:posterPrompt()}]}]})});
    if(r.status===429)return res.status(429).json({code:'rate_limited'});
    if(!r.ok)return res.status(502).json({code:'upstream_error',detail:(await r.text()).slice(0,300)});
    const data=await r.json();
    const text=(data.content||[]).filter(c=>c.type==='text').map(c=>c.text).join('');
    const a=text.indexOf('{'),b=text.lastIndexOf('}');
    if(a<0||b<a)return res.status(502).json({code:'invalid_json'});
    return res.status(200).json(JSON.parse(text.slice(a,b+1)));
  }catch(e){return res.status(502).json({code:'upstream_error'})}
}
