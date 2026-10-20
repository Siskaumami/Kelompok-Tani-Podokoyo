import { useId } from 'react';
import { Logo } from './ui';

export function KosabangsaLogoSlot(){return <img className="kosabangsa-logo" src="/kosabangsa-logo.webp" alt="Kosabangsa" width={1487} height={393}/>;}
export function ProgramIdentity({compact=false}:{compact?:boolean}){return <div className={'program-identity '+(compact?'compact':'')}><KosabangsaLogoSlot/></div>;}
export function CoBrandIdentity({variant='public'}:{variant?:'public'|'login'|'sidebar'|'footer'}){const context={public:'public-brand',login:'auth-brand',sidebar:'sidebar-brand',footer:'footer-brand'}[variant];return <div className={'co-brand '+context}><Logo/><span className="brand-divider" aria-hidden="true"/><ProgramIdentity compact={variant==='public'||variant==='footer'}/></div>;}

const houses=[
 [1005,441,.46,0],[1026,446,.39,2],[1043,458,.5,1],[1020,464,.48,0],[1069,471,.43,2],
 [995,480,.52,1],[1048,489,.57,0],[1082,492,.46,1],[1111,506,.58,2],[1074,517,.62,0],
 [977,507,.58,2],[1004,516,.7,0],[1035,528,.59,1],[1101,533,.61,2],[1138,526,.53,0],
 [983,543,.65,1],[1015,553,.6,2],[1051,554,.75,0],[1087,566,.64,1],[1127,558,.69,0],
 [1162,551,.57,2],[1155,581,.66,0],[1194,581,.72,1],[1218,601,.55,2],[1113,591,.78,2],
 [977,578,.68,0],[1005,590,.82,2],[1044,586,.66,1],[1065,610,.78,0],[1102,624,.69,1],
 [1144,615,.85,0],[1187,626,.73,2],[1230,633,.83,0],[1259,655,.67,1],[1203,655,.73,2],
 [956,606,.73,2],[993,626,.91,1],[1034,641,.78,0],[1074,654,.86,2],[1125,651,.8,1],
 [1167,675,.86,0],[1241,682,.9,2],[1289,693,.8,0],[1308,716,.9,1],[1242,719,.93,0],
 [975,669,.86,0],[1017,690,1.03,2],[1068,687,.92,1],[1111,708,1.07,0],[1157,716,.92,2],
 [1205,746,1.1,0],[1264,757,1,2],[1046,729,1.02,0],[1095,758,1.13,1],[1152,770,1.03,2]
];
const trees=[[601,259,.38],[631,243,.35],[667,228,.38],[708,239,.32],[746,267,.37],[789,293,.34],[920,341,.49],[970,385,.5],[1004,420,.5],[1274,531,.72],[1301,577,.72],[1332,618,.9],[914,566,.85],[890,622,1.1],[847,681,1.36],[784,738,1.55],[1389,665,1.1],[1432,707,1.26]];

function Landscape({format='wide',fill=false}:{format?:'wide'|'portrait'|'tablet'|'auth-tablet';fill?:boolean}){
 const id='podokoyo-'+useId().replace(/:/g,'');
 const ref=(name:string)=>`url(#${id}-${name})`;
 return <svg className={'highland-drawing '+format} viewBox={format==='portrait'?'0 0 600 1100':format==='tablet'?'0 0 1100 850':format==='auth-tablet'?'0 0 700 1000':'0 0 1600 1000'} preserveAspectRatio={format==='auth-tablet'?'xMidYMax slice':format!=='wide'?'none':fill?'xMidYMax slice':'xMidYMax meet'} focusable="false">
 <defs>
  <linearGradient id={id+'-sky'} x2=".25" y2="1"><stop stopColor="#dbe2df"/><stop offset="1" stopColor="#eeede3"/></linearGradient>
  <linearGradient id={id+'-far'} x2=".2" y2="1"><stop stopColor="#92a6a4"/><stop offset="1" stopColor="#c2cfca"/></linearGradient>
  <linearGradient id={id+'-ridge'} x1=".1" y1="0" x2=".9" y2="1"><stop stopColor="#4c6b60"/><stop offset=".5" stopColor="#68806b"/><stop offset="1" stopColor="#385b4d"/></linearGradient>
  <linearGradient id={id+'-field'} x2=".8" y2="1"><stop stopColor="#83906a"/><stop offset=".6" stopColor="#617653"/><stop offset="1" stopColor="#365844"/></linearGradient>
  <linearGradient id={id+'-near'} x2=".4" y2="1"><stop stopColor="#566f4c"/><stop offset="1" stopColor="#264f40"/></linearGradient>
  <radialGradient id={id+'-mist'}><stop stopColor="#ecf0e9" stopOpacity=".9"/><stop offset=".48" stopColor="#ecf0e9" stopOpacity=".54"/><stop offset="1" stopColor="#ecf0e9" stopOpacity="0"/></radialGradient>
  <linearGradient id={id+'-cloud'} x2=".1" y2="1"><stop stopColor="#a8bcb7" stopOpacity=".32"/><stop offset=".6" stopColor="#dae3dd" stopOpacity=".6"/><stop offset="1" stopColor="#f6f5ed" stopOpacity="0"/></linearGradient>
  <radialGradient id={id+'-clearing'} rx=".7" ry=".65"><stop stopColor="#f6f5ed" stopOpacity=".98"/><stop offset=".55" stopColor="#f6f5ed" stopOpacity=".88"/><stop offset="1" stopColor="#f6f5ed" stopOpacity="0"/></radialGradient>
  <linearGradient id={id+'-vertical-sky'} x2=".15" y2="1"><stop stopColor="#e5ebe3"/><stop offset=".45" stopColor="#f0f1e8"/><stop offset="1" stopColor="#d4decd"/></linearGradient>
  <filter id={id+'-cloud-soft'} x="-10%" y="-20%" width="120%" height="140%"><feGaussianBlur stdDeviation="8"/></filter>
  <linearGradient id={id+'-roof'} x2=".5" y2="1"><stop stopColor="#92715a"/><stop offset="1" stopColor="#5b4f43"/></linearGradient>
  <linearGradient id={id+'-roof-metal'} x2=".4" y2="1"><stop stopColor="#a5a69a"/><stop offset="1" stopColor="#6a7266"/></linearGradient>
  <filter id={id+'-texture'} x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".12 .18" numOctaves="2" seed="17" stitchTiles="stitch"/><feColorMatrix type="saturate" values="0"/></filter>
  <pattern id={id+'-earth-texture'} width="128" height="128" patternUnits="userSpaceOnUse"><rect width="128" height="128" filter={ref('texture')} opacity=".14"/></pattern>
  <pattern id={id+'-scrub'} width="51" height="39" patternUnits="userSpaceOnUse"><path d="M3 17l3-4 2 6 4-2M21 31l3-6 3 4 5-1M39 8l3-3 2 5M15 5l2 3" fill="none" stroke="#173f2e" strokeOpacity=".12" strokeWidth="2"/></pattern>
  <pattern id={id+'-rows'} width="18" height="24" patternUnits="userSpaceOnUse" patternTransform="rotate(-16)"><path d="M0 0H18M0 4H18" fill="none" stroke="#d4d4a3" strokeOpacity=".18" strokeWidth="1"/></pattern>
  <pattern id={id+'-tiles'} width="5" height="4" patternUnits="userSpaceOnUse"><path d="M0 0H5M2 0V4" fill="none" stroke="#473f33" strokeOpacity=".28" strokeWidth=".6"/></pattern>
  <pattern id={id+'-grain'} width="31" height="29" patternUnits="userSpaceOnUse"><path d="M3 3h1M16 21h1M26 9h1" stroke="#263f34" strokeOpacity=".11" strokeWidth="1"/></pattern>
  <g id={id+'-tree'}>
   <path d="M14 94c-2-38 4-61 1-91m0 61L2 36m13 14L25 21M13 74L1 58m14 5l14-24M15 30L6 12" stroke="#545b46" strokeWidth="1.4" fill="none"/>
   <path d="M12 3c-4-8-7 0-5 5-5 2-3 8 1 10-7 5-3 10 2 9-2 8 4 13 7 8 5 6 9 1 5-5 7-3 4-10-1-11 4-6-1-9-4-7 4-6-1-13-5-9zM1 29c-5 2-4 7 0 9-3 6 1 10 5 7 4 1 7-4 3-8 4-6-4-12-8-8zM24 33c-4-5-9 1-6 6-4 6-1 11 3 9 2 5 8 5 8 0 6-2 4-9 0-10 1-3-2-7-5-5zM3 55c-4-2-7 3-4 6-2 4 3 8 6 5 4 1 6-4 3-6 1-3-2-6-5-5z" fill="#49624c"/>
  </g>
  <g id={id+'-bare-tree'} fill="none" stroke="#61624c" strokeWidth="1.2">
   <path d="M14 94c-1-33 0-56 2-94M14 68L2 43m13 9L28 26M15 35L6 14m9 5L22 3M9 57L0 55m21-16l11-3M8 20L2 18m14 20l-6-7"/>
   <path d="M12 13l5-9 4 8-3 9 5 7-6 6-6-3 1-8-4-4zM3 40l6 4-2 9-6-1-2-6zM25 22l5 4-2 10-8-2 1-6z" fill="#617351" stroke="none"/>
  </g>
  {[['#c4c5b0','#93967d'],['#a6b8ae','#718d7f'],['#b5a89f','#8c8675']].map(([wall,side],i)=><g id={id+'-house-'+i} key={wall}>
   <path d="M-20-2v20l30 4 18-9V-7L1-13z" fill={wall}/><path d="M10-2v24l18-9V-7z" fill={side}/>
   <path d="M-27-4L-8-18l26 3L35-3 10 2z" fill={ref(i===1?'roof-metal':'roof')}/><path d="M-27-4L-8-18l26 3L35-3 10 2z" fill={ref('tiles')}/>
   <path d="M-8-18L10 2l25-5-17-12z" fill="#574f42" opacity=".22"/>
   <path d="M-13 4h6v5h-6zM0 6h5v14H0zM16 3l6-2v7l-6 2z" fill="#4b6255" opacity=".65"/>
   {i===2&&<path d="M-18 11l28 4 18-9M-17 14h4v4h-4m7-3h4v4h-4" stroke="#e4daca" strokeWidth="1.5" fill="none"/>}
   <path d="M-23 18l33 6 21-11" stroke="#334e3b" strokeOpacity=".3" strokeWidth="2" fill="none"/>
  </g>)}
 </defs>
 {format==='wide'?<><rect width="1600" height="1000" fill={ref('sky')}/>
 <g>
  <path d="M0 462c67-16 91-68 151-54 47 8 63-55 105-46 26 5 36-11 58-30 37-34 65-33 107-22 57 14 72-59 114-43 41 15 51-78 91-82 22-3 37 12 57-8 26-27 50-37 72-19 29 25 47 15 74 0 25-13 41 1 61 8 30 10 49-38 82-31 48 11 64 58 111 69 31 8 41-10 76 9 40 22 61 71 105 75 47 4 68 34 105 33 53-2 85 50 132 61 53 13 90 53 169 77v650H0z" fill={ref('far')}/>
  <path d="M446 662c46-93 35-158 83-244 31-57 67-78 100-134 18-31 42-49 65-53 23-5 41-10 61 9 17 18 33 36 56 47 21 11 36 43 63 57 23 12 52 9 75 29 27 24 27 49 56 64 35 18 47 48 69 78 15 20 51 24 77 49 25 25 43 48 72 67 38 24 61 32 95 54 48 31 67 73 120 92l112 43v400H366z" fill={ref('ridge')}/>
  <path d="M690 237c-23 36-35 71-44 122-10 57-43 89-57 148-10 43-7 88-36 138 70-66 67-127 102-168 51-60 53-155 76-241z" fill="#93a18a" opacity=".2"/>
  <path d="M754 246c-13 67 17 100-4 162-21 58-1 96-14 151 48-51 36-90 69-129 20-26 34-29 68-21-20-37-64-33-70-73-4-30-32-58-49-90z" fill="#234f40" opacity=".19"/>
  <path d="M843 329c36 49 36 84 49 128 20 72 51 72 54 148 28-76-9-96-11-143-2-52-44-102-92-133zM984 414c24 63 57 60 65 125 5 38 29 72 34 108 19-49 4-74-11-100-29-51-10-79-88-133z" fill="#a2ac86" opacity=".16"/>
  <path d="M446 662c46-93 35-158 83-244 31-57 67-78 100-134 18-31 42-49 65-53 23-5 41-10 61 9 17 18 33 36 56 47 21 11 36 43 63 57 23 12 52 9 75 29 27 24 27 49 56 64 35 18 47 48 69 78 15 20 51 24 77 49 25 25 43 48 72 67 38 24 61 32 95 54 48 31 67 73 120 92l112 43v400H366z" fill={ref('scrub')}/>
  <path d="M304 704c67-44 122-58 166-83 42-24 72 14 112-7 74-40 117-88 166-87 40 1 56 39 99 23 48-17 77-125 128-138 27-7 37 43 71 56 37 14 50 46 87 59 54 19 68 72 109 107 44 38 80 47 126 75 72 44 135 66 232 89V1000H0z" fill={ref('field')}/>
  <path d="M305 704c67-44 122-58 166-83 42-24 72 14 112-7 74-40 117-88 166-87 40 1 56 39 99 23 48-17 77-125 128-138 27-7 37 43 71 56 37 14 50 46 87 59 54 19 68 72 109 107 44 38 80 47 126 75 72 44 135 66 232 89V1000H0z" fill={ref('scrub')}/>
  <path d="M666 615c36-18 53-41 92-43l54 33c-25 25-59 41-96 48zM453 737c42-16 76-12 113-22l29 43-84 26zM775 735c34-19 77-27 110-54l40 42c-31 19-79 49-111 48z" fill="#a5a47a" opacity=".38"/>
  <path d="M591 679c33-4 63-20 87-33l26 48-75 32zM849 609c34-23 50-67 70-89l28 33c-14 38-36 68-63 84zM1198 792c54-6 92 10 141 36l-27 45-95-33z" fill="#6f7150" opacity=".46"/>
  <g fill="none" stroke="#d7d2a7" strokeOpacity=".28" strokeWidth="2">
   <path d="M373 719c175-104 222-27 353-94s159-125 255-77M307 780c209-119 267-51 409-103s176-121 280-94M232 846c223-115 296-49 464-104s213-120 332-89M182 917c213-126 332-32 493-91s255-126 399-76"/>
   <path d="M1043 754c84-47 179-35 369 77M1060 787c99-33 189-3 352 90M1052 830c105-16 197 17 341 100"/>
  </g>
  <path d="M993 424c-24 37-13 55 36 93s78 64 93 92 62 51 98 79 79 46 92 94" stroke="#c8baa0" strokeWidth="9" fill="none" opacity=".72"/>
  <g className="highland-village" opacity=".9">{houses.map(([x,y,scale,color],i)=><use href={'#'+id+'-house-'+color} transform={`translate(${x} ${y}) rotate(${(i%5-2)*2}) scale(${scale} ${scale*(i%4===0?1.22:1)}) skewY(${i%3-1})`} key={i}/>)}</g>
  <g>{trees.map(([x,y,scale],i)=><use href={'#'+id+(i%3===0?'-bare-tree':'-tree')} transform={`translate(${x} ${y-94*scale}) scale(${scale}) skewX(${i%2?2:-3})`} key={i}/>)}</g>
  <path d="M0 937c201-12 231-81 359-73s196 43 335 17 247-12 405 50 309-93 501-62v131H0z" fill={ref('near')}/>
  <path d="M0 937c201-12 231-81 359-73s196 43 335 17 247-12 405 50 309-93 501-62v131H0z" fill={ref('scrub')}/>
  <rect width="1600" height="1000" fill={ref('grain')}/>
  <rect width="1600" height="1000" fill={ref('earth-texture')} opacity=".7"/>
  <g className="highland-mist highland-mist-far" fill={ref('mist')}><ellipse cx="793" cy="373" rx="590" ry="85"/><ellipse cx="1150" cy="342" rx="360" ry="57"/><ellipse cx="585" cy="392" rx="280" ry="46"/></g>
  <g className="highland-mist highland-mist-near" fill={ref('mist')} opacity=".7"><ellipse cx="686" cy="623" rx="450" ry="58"/><ellipse cx="1039" cy="616" rx="275" ry="37"/></g>
  <g className="highland-leaves" stroke="#2e5140" strokeWidth="2" fill="#3d624b" opacity=".7">
   <path d="M1460 1000c-8-84-28-149-68-189m53 117l-55-37m64 76l37-66" fill="none"/>
   <path d="M1407 829c-26 5-42-14-49-33 32-2 45 11 49 33zM1433 882c-26 7-42-9-51-28 30-5 47 7 51 28zM1451 924c4-31 21-44 43-47-3 28-18 45-43 47z"/>
  </g>
 </g>
 </>:format==='portrait'?<>
  <rect width="600" height="1100" fill={ref('vertical-sky')}/>
  <g filter={ref('cloud-soft')}>
  <path d="M-60 92c45-31 52-60 97-55 28 3 29-29 61-22 22 5 24 18 47 8 35-16 46 25 72 19 37-8 58 30 85 26 56-9 78 28 124 20 61-11 98 23 174 11v180H-60z" fill={ref('cloud')}/>
  <path d="M-40 177c68-29 75-65 122-52 34 9 39-31 78-22 38 8 48-34 82-21 34 14 44-26 77-17 49 12 53-45 100-37 35 7 37 36 68 33 41-4 50 30 113 16v253H-40z" fill={ref('cloud')} opacity=".75"/>
  </g>
  <path d="M-45 388c39-56 60-49 87-86 27-38 57-18 83-55 24-35 43-4 72-35 29-31 43-3 66-16 33-19 46-64 81-69 30-4 39 22 62 14 31-12 38 35 65 27 33-9 45 55 70 52 31-3 50 40 83 48v552H-45z" fill={ref('far')} opacity=".36"/>
  <path d="M198 537c27-80 61-102 78-163 11-38 43-55 61-95 20-46 49-39 69-69 22-32 39-12 53 9 16 24 34 27 47 55 18 40 44 29 65 66l58 61v570H140z" fill={ref('ridge')} opacity=".26"/>
  <g fill={ref('mist')}><ellipse cx="130" cy="95" rx="290" ry="68"/><ellipse cx="432" cy="205" rx="330" ry="92"/><ellipse cx="290" cy="354" rx="410" ry="112"/></g>
  <rect y="245" width="600" height="540" fill={ref('clearing')}/>
  <g className="highland-ground">
  <path d="M-45 875c58-78 100-100 155-116 57-17 68-91 115-89 42 2 65 52 105 29 42-25 51-71 82-62 43 13 38 61 71 70 41 12 73 72 117 81v312H-45z" fill={ref('field')} opacity=".72"/>
  <path d="M-45 942c92-55 135-19 207-78 52-43 78-15 122-49 51-40 54-78 91-70 36 9 50 54 94 66 41 11 72 55 131 68v221H-45z" fill={ref('ridge')} opacity=".8"/>
  <path d="M-30 1014c95-46 138-14 216-60 58-35 82-9 137-37 62-32 108-9 167 15 42 17 77 32 129 28v140H-30z" fill={ref('near')} opacity=".82"/>
  <g fill="none" stroke="#d4d3a8" strokeWidth="2" strokeOpacity=".38"><path d="M-30 910c102-90 173-51 245-100M-18 944c103-85 178-50 245-100M-16 980c112-85 178-41 255-97M20 1029c111-70 171-30 249-79M345 965c77-42 155-11 277 55M336 994c95-36 176-4 276 52M335 1027c102-24 177 9 276 57"/></g>
  <path d="M143 758c-16 31-11 50 35 79s66 44 88 64 59 24 82 48 64 26 75 58" stroke="#c8baa0" strokeWidth="6" fill="none" opacity=".8"/>
  <g className="highland-village" transform="translate(-710 380) scale(.85)" opacity=".92">{houses.map(([x,y,scale,color],i)=><use href={'#'+id+'-house-'+color} transform={`translate(${x} ${y}) rotate(${(i%5-2)*2}) scale(${scale})`} key={i}/>)}</g>
  <g>{[[70,900,.75],[46,945,.9],[28,992,1.05],[510,868,.7],[538,906,.86],[565,954,1.1]].map(([x,y,scale],i)=><use href={'#'+id+(i%2?'-bare-tree':'-tree')} transform={`translate(${x} ${y-94*scale}) scale(${scale})`} key={i}/>)}</g>
  <g fill={ref('mist')}><ellipse cx="180" cy="716" rx="370" ry="120"/><ellipse cx="380" cy="867" rx="250" ry="45"/><ellipse cx="90" cy="969" rx="210" ry="40"/></g>
  </g>
  <rect width="600" height="1100" fill={ref('grain')}/>
 </>:format==='auth-tablet'?<>
  <rect width="700" height="1000" fill={ref('vertical-sky')}/>
  <g filter={ref('cloud-soft')} fill={ref('cloud')}>
   <path d="M-70 61c56-35 74-63 118-49 31 10 41-25 71-20 37 7 47 35 78 26 36-10 52 24 87 17 47-10 64 29 109 17 56-16 72 17 121 10 82-12 120 24 216 3v185H-70z"/>
   <path d="M-30 169c63-32 87-68 127-53 32 12 47-20 82-13 39 9 50-34 89-18 34 14 55-25 92-14 48 15 63-36 99-25 48 15 58 48 101 39 47-9 78 31 140 24v223H-30z" opacity=".8"/>
  </g>
  <path d="M-30 376c53-51 73-65 105-91 36-30 54-5 82-32 29-29 42-10 69-35 35-33 52-4 76-23 38-29 49-78 83-77 32 1 40 30 65 20 28-12 49 34 71 31 37-5 51 52 82 51 38-1 59 49 97 64v716H-30z" fill={ref('far')} opacity=".4"/>
  <path d="M-70 756c52-57 91-105 141-152c48-87 67-91 96-159 22-53 49-56 69-103 19-45 40-39 62-73 28-42 48-22 66-44 27-32 45-14 64 10 25 30 44 28 63 62 22 40 42 31 62 67 22 38 54 45 80 77l67 43v516H-70z" fill={ref('ridge')} opacity=".29"/>
  <g fill={ref('mist')}><ellipse cx="210" cy="93" rx="330" ry="73"/><ellipse cx="510" cy="205" rx="340" ry="88"/><ellipse cx="240" cy="365" rx="390" ry="107"/></g>
  <ellipse cx="252" cy="334" rx="570" ry="345" fill={ref('clearing')}/>
  <path d="M-45 801c87-73 122-85 172-113 45-25 65-91 111-86 45 5 61 43 101 15 40-27 46-70 80-63 44 10 57 73 93 84 49 15 77 81 118 93l70 31v238H-45z" fill={ref('field')} opacity=".75"/>
  <path d="M-35 923c107-77 146-48 225-100 59-39 72-91 113-105 40-14 48-66 79-66 38 0 50 59 85 69 37 11 64 55 104 70 43 16 72 50 129 68v141H-35z" fill={ref('ridge')} opacity=".82"/>
  <path d="M-30 992c109-52 164-21 252-67 66-34 94-11 153-38 71-32 117-1 181 22 47 16 89 37 144 32v59H-30z" fill={ref('near')} opacity=".88"/>
  <g fill="none" stroke="#d4d3a8" strokeWidth="2" strokeOpacity=".35"><path d="M-22 828c117-79 177-53 250-109M-28 870c141-80 189-44 278-111M-10 913c148-69 205-34 296-97M26 965c145-60 201-20 284-76M390 905c91-38 174-12 316 65M377 940c108-29 198 7 329 56"/></g>
  <path d="M295 723c-14 26-11 41 28 67s57 41 73 60 52 35 74 55 56 31 66 58" stroke="#c8baa0" strokeWidth="5" fill="none" opacity=".75"/>
  <g className="highland-village" transform="translate(-350 450) scale(.65)" opacity=".91">{houses.map(([x,y,scale,color],i)=><use href={'#'+id+'-house-'+color} transform={`translate(${x} ${y}) rotate(${(i%5-2)*2}) scale(${scale})`} key={i}/>)}</g>
  <g>{[[204,829,.66],[183,881,.85],[160,929,1.04],[546,837,.64],[568,888,.85],[598,939,1.07]].map(([x,y,scale],i)=><use href={'#'+id+(i%2?'-bare-tree':'-tree')} transform={`translate(${x} ${y-94*scale}) scale(${scale})`} key={i}/>)}</g>
  <g fill={ref('mist')}><ellipse cx="186" cy="659" rx="370" ry="117"/><ellipse cx="372" cy="816" rx="280" ry="47"/><ellipse cx="164" cy="919" rx="250" ry="45"/></g>
  <rect width="700" height="1000" fill={ref('grain')}/>
 </>:<>
  <rect width="1100" height="850" fill={ref('vertical-sky')}/>
  <path d="M-30 105c87-47 136-18 204-55 54-29 91 15 136-4 65-27 90 35 142 23 65-15 113 37 173 22 89-24 130 42 208 14 100-36 167 12 297-6v191H-30z" fill={ref('cloud')}/>
  <path d="M290 445c64-60 89-86 135-92 38-5 68-60 100-51 34 10 42-74 78-66 42 9 43-74 85-70 36 3 42-47 71-37 45 16 53-44 94-30 44 15 49 66 85 62 51-6 53 59 96 57 38-2 75 67 116 63v569H290z" fill={ref('far')} opacity=".72"/>
  <path d="M416 692c50-100 65-132 98-213 26-66 46-74 71-142 19-54 46-54 67-91 26-45 44-31 67-53 28-29 45-9 58 14 19 34 49 32 62 64 22 53 59 41 81 86 29 59 57 47 81 91 28 50 54 60 99 83v319H416z" fill={ref('ridge')} opacity=".82"/>
  <path d="M259 851c99-100 148-103 211-145 60-39 73-118 128-110 50 6 75-56 115-100 40-45 51-62 87-36 39 28 55 67 91 82 52 22 77 87 123 109 30 15 53 29 86 33v166H259z" fill={ref('field')}/>
  <path d="M238 850c131-38 170-18 267-54 105-40 132-17 219-52 80-31 107-1 178 25 61 22 121-4 198 32v49H238z" fill={ref('near')}/>
  <path d="M753 451c-19 27-10 45 28 74s60 51 74 73 48 39 77 61 63 37 73 75" stroke="#c8baa0" strokeWidth="7" fill="none" opacity=".7"/>
  <g fill="none" stroke="#d4d3a8" strokeWidth="2" strokeOpacity=".3"><path d="M287 792c156-99 198-51 299-107s118-101 198-62M284 826c172-90 202-41 319-92s136-89 210-53M835 741c69-37 142-17 255 44M830 779c87-28 158-3 264 40"/></g>
  <g className="highland-village" transform="translate(-53 100) scale(.8)" opacity=".9">{houses.map(([x,y,scale,color],i)=><use href={'#'+id+'-house-'+color} transform={`translate(${x} ${y}) rotate(${(i%5-2)*2}) scale(${scale})`} key={i}/>)}</g>
  <g>{[[1040,640,.7],[1068,691,.9],[643,643,.85],[615,705,1.15]].map(([x,y,scale],i)=><use href={'#'+id+(i%2?'-bare-tree':'-tree')} transform={`translate(${x} ${y-94*scale}) scale(${scale})`} key={i}/>)}</g>
  <rect width="1100" height="850" fill={ref('grain')}/>
  <g fill={ref('mist')}><ellipse cx="430" cy="130" rx="540" ry="85"/><ellipse cx="710" cy="339" rx="480" ry="90"/><ellipse cx="630" cy="520" rx="400" ry="70"/><ellipse cx="925" cy="697" rx="240" ry="39"/></g>
 </>}
 </svg>;
}

export function HighlandScene({variant='hero'}:{variant?:'hero'|'heading'|'auth'|'auth-mobile'}){return <div className={'highland-scene highland-scene-'+variant} aria-hidden="true">{variant!=='auth-mobile'&&<Landscape fill={variant==='heading'}/>}{variant==='auth'&&<Landscape format="auth-tablet"/>}{variant!=='auth'&&<Landscape format="portrait"/>}{variant!=='auth'&&variant!=='auth-mobile'&&<Landscape format="tablet"/>}<span className="highland-cloud highland-cloud-one"/><span className="highland-cloud highland-cloud-two"/></div>;}
