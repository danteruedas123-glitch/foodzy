const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

const FV = firebase.firestore.FieldValue;
const RULES = fs.readFileSync(
  process.env.RULES_PATH || path.join(__dirname, '..', 'firestore.rules'),
  'utf8',
);
const [HOST, PORT] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085').split(':');

let env;

// Datos de partida: H1 de ana (dueña) y bea; H2 de luis; HV vacío.
async function sembrar() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('hogares/H1').set({ miembros: ['ana', 'bea'], codigo: 'AAA111', creadoPor: 'ana' });
    await db.doc('hogares/H2').set({ miembros: ['luis'], codigo: 'LLL222', creadoPor: 'luis' });
    await db.doc('hogares/HV').set({ miembros: [], codigo: 'VVV333', creadoPor: 'zed' });
    await db.doc('hogares/H1/alimentos/a1').set({ nombre: 'Arroz' });
    await db.doc('invitaciones/AAA111').set({ hogarId: 'H1' });
  });
}

const como = (uid) => env.authenticatedContext(uid).firestore();
const anonimo = () => env.unauthenticatedContext().firestore();

const casos = [
  // ── Crear ──
  ['crear: una persona crea un hogar para ella sola', async () =>
    assertSucceeds(como('sara').doc('hogares/N1').set({ miembros: ['sara'], codigo: 'N1N1N1', creadoPor: 'sara' }))],
  ['crear: NO se puede crear un hogar metiendo a otra persona', async () =>
    assertFails(como('sara').doc('hogares/N1').set({ miembros: ['sara', 'ana'], codigo: 'N1N1N1', creadoPor: 'sara' }))],
  ['crear: NO se puede crear un hogar a nombre de otra persona', async () =>
    assertFails(como('sara').doc('hogares/N1').set({ miembros: ['sara'], codigo: 'N1N1N1', creadoPor: 'ana' }))],
  ['crear: sin sesión no se puede', async () =>
    assertFails(anonimo().doc('hogares/N1').set({ miembros: ['x'], codigo: 'N1N1N1', creadoPor: 'x' }))],

  // ── Leer ──
  ['leer: un miembro ve su hogar', async () => assertSucceeds(como('bea').doc('hogares/H1').get())],
  ['leer: quien no es miembro NO lo ve', async () => assertFails(como('luis').doc('hogares/H1').get())],

  // ── Unirse ──
  ['unirse: una persona se añade a sí misma a un hogar con gente', async () =>
    assertSucceeds(como('luis').doc('hogares/H1').update({ miembros: FV.arrayUnion('luis') }))],
  ['unirse: NO puede añadir a otra persona en vez de a sí misma', async () =>
    assertFails(como('luis').doc('hogares/H1').update({ miembros: FV.arrayUnion('zoe') }))],
  ['unirse: NO puede añadirse y de paso sacar a alguien', async () =>
    assertFails(como('luis').doc('hogares/H1').update({ miembros: ['ana', 'luis'] }))],
  ['unirse: NO puede unirse a un hogar abandonado (vacío)', async () =>
    assertFails(como('luis').doc('hogares/HV').update({ miembros: FV.arrayUnion('luis') }))],
  ['unirse: un miembro NO puede añadir a un tercero', async () =>
    assertFails(como('bea').doc('hogares/H1').update({ miembros: FV.arrayUnion('zoe') }))],

  // ── Salir ──
  ['salir: un miembro se quita a sí mismo', async () =>
    assertSucceeds(como('bea').doc('hogares/H1').update({ miembros: FV.arrayRemove('bea') }))],
  ['salir: un miembro que no es dueño NO puede quitar a otra persona', async () =>
    assertFails(como('bea').doc('hogares/H1').update({ miembros: FV.arrayRemove('ana') }))],
  ['salir: quien no es miembro NO puede quitar a nadie', async () =>
    assertFails(como('luis').doc('hogares/H1').update({ miembros: FV.arrayRemove('ana') }))],

  // ── Dueño ──
  ['dueño: puede quitar a otra persona', async () =>
    assertSucceeds(como('ana').doc('hogares/H1').update({ miembros: FV.arrayRemove('bea') }))],
  ['dueño: NO puede quitar a alguien y añadir a otro a la vez', async () =>
    assertFails(como('ana').doc('hogares/H1').update({ miembros: ['ana', 'zoe'] }))],
  ['dueño: NO puede vaciar el hogar quitando a todos', async () =>
    assertFails(como('ana').doc('hogares/H1').update({ miembros: [] }))],

  // ── Campos que no se tocan ──
  ['campos: el dueño NO puede cambiar el código', async () =>
    assertFails(como('ana').doc('hogares/H1').update({ codigo: 'HACK99' }))],
  ['campos: un miembro NO puede cambiar el código', async () =>
    assertFails(como('bea').doc('hogares/H1').update({ codigo: 'HACK99' }))],
  ['campos: un miembro NO puede volverse dueño', async () =>
    assertFails(como('bea').doc('hogares/H1').update({ creadoPor: 'bea' }))],
  ['campos: NO se puede salir y cambiar el código en el mismo cambio', async () =>
    assertFails(como('bea').doc('hogares/H1').update({ miembros: FV.arrayRemove('bea'), codigo: 'HACK99' }))],
  ['campos: nadie puede borrar un hogar', async () =>
    assertFails(como('ana').doc('hogares/H1').delete())],

  // ── Despensa del hogar ──
  ['despensa: un miembro lee y escribe', async () => {
    await assertSucceeds(como('bea').doc('hogares/H1/alimentos/a1').get());
    await assertSucceeds(como('bea').doc('hogares/H1/alimentos/a2').set({ nombre: 'Leche' }));
  }],
  ['despensa: quien no es miembro NO accede', async () => {
    await assertFails(como('luis').doc('hogares/H1/alimentos/a1').get());
    await assertFails(como('luis').doc('hogares/H1/alimentos/a2').set({ nombre: 'Leche' }));
  }],
  ['despensa: al salir, la persona pierde el acceso', async () => {
    await assertSucceeds(como('bea').doc('hogares/H1').update({ miembros: FV.arrayRemove('bea') }));
    await assertFails(como('bea').doc('hogares/H1/alimentos/a1').get());
  }],

  // ── Los pasos reales de la app ──
  ['app: flujo completo de unirse (entrar, asignar hogar, salir del anterior)', async () => {
    const db = como('luis');
    await assertSucceeds(db.doc('invitaciones/AAA111').get());
    await assertSucceeds(db.doc('hogares/H1').update({ miembros: FV.arrayUnion('luis') }));
    await assertSucceeds(db.doc('usuarios/luis').set({ hogarId: 'H1' }, { merge: true }));
    await assertSucceeds(db.doc('hogares/H2').update({ miembros: FV.arrayRemove('luis') }));
    await assertSucceeds(db.doc('hogares/H1/alimentos/a1').get());
  }],
  ['app: deshacer la entrada cuando algo falla (arrayRemove de sí mismo)', async () => {
    const db = como('luis');
    await assertSucceeds(db.doc('hogares/H1').update({ miembros: FV.arrayUnion('luis') }));
    await assertSucceeds(db.doc('hogares/H1').update({ miembros: FV.arrayRemove('luis') }));
  }],
  ['app: flujo completo de salir (crear hogar propio en lote y salir del compartido)', async () => {
    const db = como('bea');
    const lote = db.batch();
    lote.set(db.doc('hogares/B1'), {
      miembros: ['bea'], codigo: 'BBB444', creadoPor: 'bea',
      creado: FV.serverTimestamp(),
    });
    lote.set(db.doc('invitaciones/BBB444'), { hogarId: 'B1' });
    lote.set(db.doc('usuarios/bea'), { hogarId: 'B1', nombre: 'Bea', email: 'b@x.co' }, { merge: true });
    await assertSucceeds(lote.commit());
    await assertSucceeds(db.doc('hogares/H1').update({ miembros: FV.arrayRemove('bea') }));
  }],
  ['app: el dueño sale de un hogar compartido y los demás siguen dentro', async () => {
    await assertSucceeds(como('ana').doc('hogares/H1').update({ miembros: FV.arrayRemove('ana') }));
    await assertSucceeds(como('bea').doc('hogares/H1').get());
  }],
  ['usuarios: solo cada quien ve y escribe lo suyo', async () => {
    await assertSucceeds(como('ana').doc('usuarios/ana').set({ hogarId: 'H1' }));
    await assertFails(como('bea').doc('usuarios/ana').get());
    await assertFails(como('bea').doc('usuarios/ana').set({ hogarId: 'H2' }));
  }],
];

(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-foodzy',
    firestore: { rules: RULES, host: HOST, port: Number(PORT) },
  });
  let bien = 0;
  const fallados = [];
  for (const [nombre, fn] of casos) {
    await sembrar();
    try {
      await fn();
      bien++;
      console.log('  ✔', nombre);
    } catch (e) {
      fallados.push(nombre);
      console.log('  ✘', nombre);
    }
  }
  console.log(`\n${bien} de ${casos.length} pruebas pasan`);
  if (fallados.length) console.log(`Fallan ${fallados.length}.`);
  await env.cleanup();
  process.exit(fallados.length ? 1 : 0);
})();
