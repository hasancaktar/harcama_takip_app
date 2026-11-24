// Firestore güvenlik kuralları testleri.
// Çalıştırma: cd firestore-tests && npm install && npm test   (JDK 21+ gerekir)
import { after, afterEach, before, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayUnion,
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  query,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  arrayRemove,
  where,
  writeBatch,
} from 'firebase/firestore';

// Beklenen PERMISSION_DENIED hatalarının konsolu kirletmesini önle.
setLogLevel('silent');

const here = dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'demo-harcama-rules';
let env;

const USERS = {
  alice: { uid: 'alice', email: 'alice@example.com' },
  bob: { uid: 'bob', email: 'bob@example.com' },
  eve: { uid: 'eve', email: 'eve@example.com' },
};

function db(user, { verified = true } = {}) {
  return env
    .authenticatedContext(user.uid, { email: user.email, email_verified: verified })
    .firestore();
}

const now = () => new Date().toISOString();

function expense(id, owner, overrides = {}) {
  return {
    id,
    ownerUid: owner,
    teamId: null,
    visibility: 'personal',
    title: 'Market',
    amountInCents: 12550,
    currency: 'TRY',
    category: 'market',
    date: now(),
    paymentMethod: 'cash',
    cardId: null,
    cardLast4: null,
    isInstallment: false,
    statementPeriod: '2026-11',
    notes: null,
    tags: [],
    status: 'active',
    createdBy: owner,
    createdAt: now(),
    updatedAt: now(),
    ...overrides,
  };
}

function card(id, owner, overrides = {}) {
  return {
    id,
    ownerUid: owner,
    teamId: null,
    isSharedWithTeam: false,
    name: 'Bonus',
    bankName: 'Garanti',
    last4Digits: '1234',
    colorHex: '#1E3A8A',
    limitInCents: 0,
    cutoffDay: 15,
    paymentDueDaysAfterCutoff: 10,
    currency: 'TRY',
    isActive: true,
    createdAt: now(),
    updatedAt: now(),
    ...overrides,
  };
}

/** Kuralları atlayarak test verisi yazar. */
async function seed(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

/** alice'in sahibi olduğu, bob'un üyesi olduğu takımı hazırlar. */
async function seedTeam({ members = ['alice', 'bob'] } = {}) {
  await seed(async (fs) => {
    await setDoc(doc(fs, 'teams/t1'), {
      id: 't1',
      name: 'Evimiz',
      ownerUid: 'alice',
      memberUids: members,
      memberCount: members.length,
      isArchived: false,
      colorHex: '#0F5132',
      createdAt: now(),
      updatedAt: now(),
    });
    for (const m of members) {
      await setDoc(doc(fs, `teams/t1/members/${m}`), {
        uid: m,
        teamId: 't1',
        role: m === 'alice' ? 'owner' : 'member',
        status: 'accepted',
        displayName: m,
        email: `${m}@example.com`,
      });
    }
  });
}

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host,
      port: Number(port),
      rules: readFileSync(resolve(here, '../firestore.rules'), 'utf8'),
    },
  });
});

afterEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe('Kimlik doğrulama ve e-posta doğrulaması', () => {
  test('oturumsuz kullanıcı hiçbir veriyi okuyamaz', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'users/alice')));
    await assertFails(getDocs(query(collection(anon, 'expenses'), where('ownerUid', '==', 'alice'))));
  });

  test('e-postası doğrulanmamış kullanıcı kendi profilini oluşturabilir', async () => {
    const fs = db(USERS.alice, { verified: false });
    await assertSucceeds(setDoc(doc(fs, 'users/alice'), { uid: 'alice', email: USERS.alice.email, displayName: 'Alice' }));
    await assertSucceeds(getDoc(doc(fs, 'users/alice')));
  });

  test('e-postası doğrulanmamış kullanıcı harcama yazamaz ve okuyamaz', async () => {
    const fs = db(USERS.alice, { verified: false });
    await assertFails(setDoc(doc(fs, 'expenses/e1'), expense('e1', 'alice')));
    await assertFails(
      getDocs(query(collection(fs, 'expenses'), where('ownerUid', '==', 'alice'), where('visibility', '==', 'personal'))),
    );
  });

  test('başka kullanıcının profili okunamaz ve yazılamaz', async () => {
    await seed((fs) => setDoc(doc(fs, 'users/alice'), { uid: 'alice', email: USERS.alice.email, displayName: 'Alice' }));
    const bob = db(USERS.bob);
    await assertFails(getDoc(doc(bob, 'users/alice')));
    await assertFails(updateDoc(doc(bob, 'users/alice'), { displayName: 'Hacked' }));
  });
});

describe('Kişisel harcamalar', () => {
  test('sahibi geçerli harcama oluşturabilir, günceller ve soft-delete yapabilir', async () => {
    const fs = db(USERS.alice);
    await assertSucceeds(setDoc(doc(fs, 'expenses/e1'), expense('e1', 'alice')));
    await assertSucceeds(updateDoc(doc(fs, 'expenses/e1'), { title: 'Market (güncel)', updatedAt: now() }));
    await assertSucceeds(updateDoc(doc(fs, 'expenses/e1'), { status: 'deleted', deletedAt: now(), deletedBy: 'alice' }));
  });

  test('başkası adına harcama oluşturulamaz', async () => {
    await assertFails(setDoc(doc(db(USERS.eve), 'expenses/e1'), expense('e1', 'alice')));
  });

  test('geçersiz tutar, uzun başlık ve hatalı dönem reddedilir', async () => {
    const fs = db(USERS.alice);
    await assertFails(setDoc(doc(fs, 'expenses/a'), expense('a', 'alice', { amountInCents: 0 })));
    await assertFails(setDoc(doc(fs, 'expenses/b'), expense('b', 'alice', { amountInCents: 12.5 })));
    await assertFails(setDoc(doc(fs, 'expenses/c'), expense('c', 'alice', { title: 'x'.repeat(101) })));
    await assertFails(setDoc(doc(fs, 'expenses/d'), expense('d', 'alice', { statementPeriod: '2026-13' })));
    await assertFails(setDoc(doc(fs, 'expenses/e'), expense('e', 'alice', { paymentMethod: 'crypto' })));
    await assertFails(setDoc(doc(fs, 'expenses/f'), expense('wrong-id', 'alice')));
  });

  test('kişisel harcama başka kullanıcıya görünmez; sahiplik devredilemez', async () => {
    await seed((fs) => setDoc(doc(fs, 'expenses/e1'), expense('e1', 'alice')));
    const eve = db(USERS.eve);
    await assertFails(getDoc(doc(eve, 'expenses/e1')));
    await assertFails(updateDoc(doc(eve, 'expenses/e1'), { title: 'x' }));
    await assertFails(deleteDoc(doc(eve, 'expenses/e1')));
    await assertFails(updateDoc(doc(db(USERS.alice), 'expenses/e1'), { ownerUid: 'eve' }));
  });

  test('kişisel liste sorgusu yalnızca kendi kayıtları için izinlidir', async () => {
    const alice = db(USERS.alice);
    const own = query(
      collection(alice, 'expenses'),
      where('ownerUid', '==', 'alice'),
      where('visibility', '==', 'personal'),
      where('status', '==', 'active'),
      where('statementPeriod', 'in', ['2026-10', '2026-11']),
    );
    await assertSucceeds(getDocs(own));
    await assertFails(getDocs(query(collection(alice, 'expenses'), where('ownerUid', '==', 'bob'))));
    await assertFails(getDocs(collection(alice, 'expenses')));
  });
});

describe('Takımlar ve takım harcamaları', () => {
  test('takım oluşturma: takım ve sahip üyeliği aynı yığında yazılır', async () => {
    const fs = db(USERS.alice);
    const batch = writeBatch(fs);
    batch.set(doc(fs, 'teams/t9'), {
      id: 't9', name: 'Aile', ownerUid: 'alice', memberUids: ['alice'], memberCount: 1, isArchived: false,
      colorHex: '#0F5132', description: null, createdAt: now(), updatedAt: now(),
    });
    batch.set(doc(fs, 'teams/t9/members/alice'), {
      uid: 'alice', teamId: 't9', role: 'owner', status: 'accepted', displayName: 'Alice', email: USERS.alice.email,
    });
    await assertSucceeds(batch.commit());
  });

  test('başkası adına veya başka üyelerle takım oluşturulamaz', async () => {
    const fs = db(USERS.eve);
    await assertFails(setDoc(doc(fs, 'teams/x'), {
      id: 'x', name: 'X', ownerUid: 'alice', memberUids: ['alice'], memberCount: 1, isArchived: false,
    }));
    await assertFails(setDoc(doc(fs, 'teams/y'), {
      id: 'y', name: 'Y', ownerUid: 'eve', memberUids: ['eve', 'bob'], memberCount: 2, isArchived: false,
    }));
  });

  test('üye olmayan takımı ve takım harcamalarını okuyamaz', async () => {
    await seedTeam();
    await seed((fs) => setDoc(doc(fs, 'expenses/te1'), expense('te1', 'bob', { visibility: 'team', teamId: 't1' })));
    const eve = db(USERS.eve);
    await assertFails(getDoc(doc(eve, 'teams/t1')));
    await assertFails(getDoc(doc(eve, 'expenses/te1')));
    await assertFails(getDocs(query(collection(eve, 'expenses'), where('teamId', '==', 't1'), where('visibility', '==', 'team'))));
    await assertFails(getDocs(collection(eve, 'teams/t1/members')));
  });

  test('takım üyesi takım harcamalarını listeleyebilir ve takıma harcama ekleyebilir', async () => {
    await seedTeam();
    await seed((fs) => setDoc(doc(fs, 'expenses/te1'), expense('te1', 'alice', { visibility: 'team', teamId: 't1' })));
    const bob = db(USERS.bob);
    await assertSucceeds(getDoc(doc(bob, 'expenses/te1')));
    await assertSucceeds(getDocs(query(
      collection(bob, 'expenses'),
      where('teamId', '==', 't1'),
      where('visibility', '==', 'team'),
      where('status', '==', 'active'),
      where('statementPeriod', '==', '2026-11'),
    )));
    await assertSucceeds(setDoc(doc(bob, 'expenses/te2'), expense('te2', 'bob', { visibility: 'team', teamId: 't1' })));
    // Üye, başkasının takım harcamasını değiştiremez.
    await assertFails(updateDoc(doc(bob, 'expenses/te1'), { title: 'değişti' }));
  });

  test('üye olunmayan takıma harcama yazılamaz', async () => {
    await seedTeam();
    await assertFails(setDoc(doc(db(USERS.eve), 'expenses/x'), expense('x', 'eve', { visibility: 'team', teamId: 't1' })));
  });

  test('takım listesi yalnızca üyesi olunan takımları döndürür', async () => {
    await seedTeam();
    await assertSucceeds(getDocs(query(collection(db(USERS.bob), 'teams'), where('memberUids', 'array-contains', 'bob'))));
    await assertFails(getDocs(collection(db(USERS.bob), 'teams')));
  });

  test('üye takım ayarlarını değiştiremez ve başkasını ekleyemez', async () => {
    await seedTeam();
    const bob = db(USERS.bob);
    await assertFails(updateDoc(doc(bob, 'teams/t1'), { name: 'Benim takımım' }));
    await assertFails(updateDoc(doc(bob, 'teams/t1'), { ownerUid: 'bob' }));
    await assertFails(updateDoc(doc(bob, 'teams/t1'), { memberUids: arrayUnion('eve') }));
  });

  test('davetsiz kullanıcı kendini takıma ekleyemez', async () => {
    await seedTeam({ members: ['alice'] });
    const eve = db(USERS.eve);
    const batch = writeBatch(eve);
    batch.set(doc(eve, 'teams/t1/members/eve'), {
      uid: 'eve', teamId: 't1', role: 'member', status: 'accepted', inviteId: 'NOPE2345',
    });
    batch.update(doc(eve, 'teams/t1'), { memberUids: arrayUnion('eve'), memberCount: increment(1) });
    await assertFails(batch.commit());
  });

  test('üye kendi isteğiyle ayrılabilir; sahip üye çıkarabilir', async () => {
    await seedTeam({ members: ['alice', 'bob', 'eve'] });
    const bob = db(USERS.bob);
    const leave = writeBatch(bob);
    leave.delete(doc(bob, 'teams/t1/members/bob'));
    leave.update(doc(bob, 'teams/t1'), { memberUids: arrayRemove('bob'), memberCount: increment(-1), updatedAt: now() });
    await assertSucceeds(leave.commit());

    const alice = db(USERS.alice);
    const remove = writeBatch(alice);
    remove.delete(doc(alice, 'teams/t1/members/eve'));
    remove.update(doc(alice, 'teams/t1'), { memberUids: arrayRemove('eve'), memberCount: increment(-1), updatedAt: now() });
    await assertSucceeds(remove.commit());
  });

  test('takım silinemez, yalnızca sahip arşivleyebilir', async () => {
    await seedTeam();
    await assertFails(deleteDoc(doc(db(USERS.alice), 'teams/t1')));
    await assertFails(updateDoc(doc(db(USERS.bob), 'teams/t1'), { isArchived: true }));
    await assertSucceeds(updateDoc(doc(db(USERS.alice), 'teams/t1'), { isArchived: true, updatedAt: now() }));
  });
});

describe('Davetler', () => {
  const future = () => Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 3600 * 1000));

  function invite(code, email, overrides = {}) {
    return {
      inviteId: code, teamId: 't1', teamName: 'Evimiz', invitedEmail: email, role: 'member',
      status: 'pending', createdBy: 'alice', createdByName: 'Alice', createdAt: Timestamp.now(),
      expiresAt: future(), ...overrides,
    };
  }

  test('yalnızca takım sahibi davet oluşturabilir', async () => {
    await seedTeam({ members: ['alice', 'bob'] });
    await assertSucceeds(setDoc(doc(db(USERS.alice), 'teams/t1/invites/ABCD2345'), invite('ABCD2345', 'eve@example.com')));
    await assertFails(setDoc(doc(db(USERS.bob), 'teams/t1/invites/WXYZ2345'), invite('WXYZ2345', 'eve@example.com', { createdBy: 'bob' })));
    // Süresi çok uzun veya rol yükseltmeli davet reddedilir.
    await assertFails(setDoc(doc(db(USERS.alice), 'teams/t1/invites/LONG2345'), invite('LONG2345', 'x@example.com', {
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 3600 * 1000)),
    })));
    await assertFails(setDoc(doc(db(USERS.alice), 'teams/t1/invites/ROLE2345'), invite('ROLE2345', 'x@example.com', { role: 'owner' })));
  });

  test('davet edilen kişi kendi davetlerini listeler; başkası listeleyemez', async () => {
    await seedTeam({ members: ['alice'] });
    await seed((fs) => setDoc(doc(fs, 'teams/t1/invites/ABCD2345'), invite('ABCD2345', 'eve@example.com')));
    const mine = (fs, email) => query(
      collectionGroup(fs, 'invites'), where('invitedEmail', '==', email), where('status', '==', 'pending'),
    );
    const res = await assertSucceeds(getDocs(mine(db(USERS.eve), 'eve@example.com')));
    if (res.size !== 1) throw new Error(`Beklenen 1 davet, bulunan ${res.size}`);
    await assertFails(getDocs(mine(db(USERS.bob), 'eve@example.com')));
  });

  async function acceptAs(user, code) {
    const fs = db(user);
    const batch = writeBatch(fs);
    batch.set(doc(fs, `teams/t1/members/${user.uid}`), {
      uid: user.uid, teamId: 't1', displayName: user.uid, email: user.email, role: 'member',
      status: 'accepted', joinedAt: now(), invitedBy: 'alice', inviteId: code,
    });
    batch.update(doc(fs, `teams/t1/invites/${code}`), { status: 'accepted', acceptedBy: user.uid, acceptedAt: serverTimestamp() });
    batch.update(doc(fs, 'teams/t1'), { memberUids: arrayUnion(user.uid), memberCount: increment(1), updatedAt: now() });
    return batch.commit();
  }

  test('geçerli davetle katılma başarılı olur ve takım verisi açılır', async () => {
    await seedTeam({ members: ['alice'] });
    await seed((fs) => setDoc(doc(fs, 'teams/t1/invites/ABCD2345'), invite('ABCD2345', 'eve@example.com')));
    await assertSucceeds(acceptAs(USERS.eve, 'ABCD2345'));
    await assertSucceeds(getDoc(doc(db(USERS.eve), 'teams/t1')));
  });

  test('başka e-postaya ait davet kullanılamaz', async () => {
    await seedTeam({ members: ['alice'] });
    await seed((fs) => setDoc(doc(fs, 'teams/t1/invites/ABCD2345'), invite('ABCD2345', 'eve@example.com')));
    await assertFails(acceptAs(USERS.bob, 'ABCD2345'));
  });

  test('süresi dolmuş veya iptal edilmiş davet kullanılamaz', async () => {
    await seedTeam({ members: ['alice'] });
    await seed(async (fs) => {
      await setDoc(doc(fs, 'teams/t1/invites/OLDX2345'), invite('OLDX2345', 'eve@example.com', {
        expiresAt: Timestamp.fromDate(new Date(Date.now() - 1000)),
      }));
      await setDoc(doc(fs, 'teams/t1/invites/REVK2345'), invite('REVK2345', 'eve@example.com', { status: 'revoked' }));
    });
    await assertFails(acceptAs(USERS.eve, 'OLDX2345'));
    await assertFails(acceptAs(USERS.eve, 'REVK2345'));
  });

  test('sahip daveti iptal edebilir; davet edilen reddedebilir', async () => {
    await seedTeam({ members: ['alice'] });
    await seed(async (fs) => {
      await setDoc(doc(fs, 'teams/t1/invites/AAAA2345'), invite('AAAA2345', 'eve@example.com'));
      await setDoc(doc(fs, 'teams/t1/invites/BBBB2345'), invite('BBBB2345', 'eve@example.com'));
    });
    await assertSucceeds(updateDoc(doc(db(USERS.alice), 'teams/t1/invites/AAAA2345'), { status: 'revoked' }));
    await assertSucceeds(updateDoc(doc(db(USERS.eve), 'teams/t1/invites/BBBB2345'), { status: 'declined', acceptedAt: serverTimestamp() }));
  });
});

describe('Kartlar', () => {
  test('sahibi kart ekler; son 4 hane dışında kart verisi kabul edilmez', async () => {
    const fs = db(USERS.alice);
    await assertSucceeds(setDoc(doc(fs, 'creditCards/c1'), card('c1', 'alice')));
    await assertFails(setDoc(doc(fs, 'creditCards/c2'), card('c2', 'alice', { last4Digits: '1234567812345678' })));
    await assertFails(setDoc(doc(fs, 'creditCards/c3'), card('c3', 'alice', { cutoffDay: 32 })));
  });

  test('paylaşılan kartı takım üyesi okur, dışarıdan biri okuyamaz', async () => {
    await seedTeam();
    await seed((fs) => setDoc(doc(fs, 'creditCards/c1'), card('c1', 'alice', { isSharedWithTeam: true, teamId: 't1' })));
    await assertSucceeds(getDoc(doc(db(USERS.bob), 'creditCards/c1')));
    await assertSucceeds(getDocs(query(
      collection(db(USERS.bob), 'creditCards'),
      where('teamId', '==', 't1'), where('isSharedWithTeam', '==', true), where('isActive', '==', true),
    )));
    await assertFails(getDoc(doc(db(USERS.eve), 'creditCards/c1')));
    await assertFails(updateDoc(doc(db(USERS.bob), 'creditCards/c1'), { name: 'x' }));
  });
});

describe('Bütçeler', () => {
  const budget = (id, owner, overrides = {}) => ({
    id, ownerUid: owner, teamId: null, visibility: 'personal', period: '2026-11',
    totalBudgetInCents: 2500000, categoryBudgetsInCents: {}, currency: 'TRY',
    createdAt: now(), updatedAt: now(), ...overrides,
  });

  test('kişisel bütçe yalnızca kanonik kimlikle ve sahibince yazılır', async () => {
    const fs = db(USERS.alice);
    await assertSucceeds(setDoc(doc(fs, 'budgets/user_alice_2026-11'), budget('user_alice_2026-11', 'alice')));
    await assertFails(setDoc(doc(fs, 'budgets/random-id'), budget('random-id', 'alice')));
    await assertFails(setDoc(doc(db(USERS.eve), 'budgets/user_alice_2026-12'), budget('user_alice_2026-12', 'alice', { period: '2026-12' })));
  });

  test('takım bütçesini yalnızca takımı kuran yazar ve siler; üyeler okur', async () => {
    await seedTeam(); // kurucu: alice, üye: bob
    const team = (owner) => budget('team_t1_2026-11', owner, { visibility: 'team', teamId: 't1' });
    await assertSucceeds(setDoc(doc(db(USERS.alice), 'budgets/team_t1_2026-11'), team('alice')));
    await assertFails(setDoc(doc(db(USERS.bob), 'budgets/team_t1_2026-11'), team('bob')));
    await assertFails(setDoc(doc(db(USERS.bob), 'budgets/team_t1_2026-12'), budget('team_t1_2026-12', 'bob', { visibility: 'team', teamId: 't1', period: '2026-12' })));
    await assertFails(deleteDoc(doc(db(USERS.bob), 'budgets/team_t1_2026-11')));
    // Devretme için takımın tüm bütçeleri dönem filtresi olmadan okunur.
    await assertSucceeds(getDocs(query(
      collection(db(USERS.bob), 'budgets'),
      where('teamId', '==', 't1'), where('visibility', '==', 'team'),
    )));
    await assertFails(setDoc(doc(db(USERS.eve), 'budgets/team_t1_2026-11'), team('eve')));
    await assertFails(getDoc(doc(db(USERS.eve), 'budgets/team_t1_2026-11')));
    await assertSucceeds(deleteDoc(doc(db(USERS.alice), 'budgets/team_t1_2026-11')));
  });

  test('eski sürümde üyenin yazdığı takım bütçesini üye silemez, kurucu siler', async () => {
    await seedTeam();
    await seed((fs) => setDoc(doc(fs, 'budgets/legacy-1'), budget('legacy-1', 'bob', { visibility: 'team', teamId: 't1' })));
    await assertFails(deleteDoc(doc(db(USERS.bob), 'budgets/legacy-1')));
    await assertSucceeds(deleteDoc(doc(db(USERS.alice), 'budgets/legacy-1')));
  });

  test('kişisel bütçeler dönem filtresi olmadan sorgulanabilir (devretme)', async () => {
    await seed((fs) => setDoc(doc(fs, 'budgets/user_alice_2026-10'), budget('user_alice_2026-10', 'alice', { period: '2026-10' })));
    await assertSucceeds(getDocs(query(
      collection(db(USERS.alice), 'budgets'),
      where('ownerUid', '==', 'alice'), where('visibility', '==', 'personal'),
    )));
    await assertFails(getDocs(query(
      collection(db(USERS.eve), 'budgets'),
      where('ownerUid', '==', 'alice'), where('visibility', '==', 'personal'),
    )));
  });

  test('eski sürümün açık kuralı (visibility=team ile herkesin yazması) kapatıldı', async () => {
    await seed((fs) => setDoc(doc(fs, 'budgets/user_alice_2026-11'), budget('user_alice_2026-11', 'alice')));
    await assertFails(setDoc(doc(db(USERS.eve), 'budgets/user_alice_2026-11'), budget('user_alice_2026-11', 'eve', { visibility: 'team', teamId: 'nope' })));
  });
});

describe('Otomatik ödemeler', () => {
  const payment = (id, owner, o = {}) => ({
    id, ownerUid: owner, teamId: null, visibility: 'personal', title: 'Elektrik',
    amountInCents: 85000, currency: 'TRY', category: 'bills', cardId: null, cardLast4: null,
    cardCutoffDay: null, dayOfMonth: 15, startDate: now(), endDate: null,
    lastPostedMonth: '2026-11', status: 'active', notes: null,
    createdAt: now(), updatedAt: now(), ...o,
  });

  test('ödeme ve aylık kaydı aynı yığında yazılır; başkası okuyamaz', async () => {
    const fs = db(USERS.alice);
    const batch = writeBatch(fs);
    batch.set(doc(fs, 'recurringPayments/r1'), payment('r1', 'alice'));
    batch.set(doc(fs, 'expenses/r1_2026-11'), expense('r1_2026-11', 'alice', {
      paymentMethod: 'auto_payment', recurringPaymentId: 'r1',
    }));
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDocs(query(collection(fs, 'recurringPayments'), where('ownerUid', '==', 'alice'))));
    await assertFails(getDoc(doc(db(USERS.eve), 'recurringPayments/r1')));
    await assertFails(setDoc(doc(db(USERS.eve), 'recurringPayments/r2'), payment('r2', 'alice')));
  });

  test('geçersiz gün, tutar veya ay reddedilir; sahiplik devredilemez', async () => {
    const fs = db(USERS.alice);
    await assertFails(setDoc(doc(fs, 'recurringPayments/r1'), payment('r1', 'alice', { dayOfMonth: 32 })));
    await assertFails(setDoc(doc(fs, 'recurringPayments/r1'), payment('r1', 'alice', { amountInCents: 0 })));
    await assertFails(setDoc(doc(fs, 'recurringPayments/r1'), payment('r1', 'alice', { lastPostedMonth: '2026-13' })));
    await assertSucceeds(setDoc(doc(fs, 'recurringPayments/r1'), payment('r1', 'alice')));
    await assertFails(setDoc(doc(fs, 'recurringPayments/r1'), payment('r1', 'bob')));
    await assertFails(updateDoc(doc(db(USERS.bob), 'recurringPayments/r1'), { status: 'cancelled' }));
    await assertSucceeds(updateDoc(doc(fs, 'recurringPayments/r1'), { status: 'cancelled', endDate: now() }));
  });

  test('takım ödemesini üyeler görür, yalnızca ekleyen değiştirir', async () => {
    await seedTeam();
    const p = payment('r3', 'bob', { visibility: 'team', teamId: 't1' });
    await assertSucceeds(setDoc(doc(db(USERS.bob), 'recurringPayments/r3'), p));
    await assertSucceeds(getDocs(query(
      collection(db(USERS.alice), 'recurringPayments'),
      where('teamId', '==', 't1'), where('visibility', '==', 'team'),
    )));
    await assertFails(updateDoc(doc(db(USERS.alice), 'recurringPayments/r3'), { status: 'cancelled' }));
    await assertFails(setDoc(doc(db(USERS.eve), 'recurringPayments/r4'), payment('r4', 'eve', { visibility: 'team', teamId: 't1' })));
  });
});

describe('Pasif kullanıcılar, öneriler, sürüm notları', () => {
  const ADMIN = { uid: 'admin', email: 'hasancaktar@gmail.com' };
  const profile = (uid, o = {}) => ({ uid, email: `${uid}@example.com`, displayName: uid, ...o });
  const feedback = (id, uid, o = {}) => ({
    id, uid, email: `${uid}@example.com`, displayName: uid, message: 'Karanlık tema harika olur',
    appVersion: '1.2.0', platform: 'android', status: 'new', createdAt: serverTimestamp(), ...o,
  });
  const notes = (version, o = {}) => ({
    version, addedTr: ['Otomatik ödemeler'], addedEn: [], removedTr: [], removedEn: [],
    fixedTr: [], fixedEn: [], published: true, ...o,
  });

  test('yönetici kullanıcıyı pasife alır; kullanıcı bunu kendisi değiştiremez', async () => {
    await seed((fs) => setDoc(doc(fs, 'users/alice'), profile('alice')));
    const alice = db(USERS.alice);
    await assertFails(updateDoc(doc(alice, 'users/alice'), { disabled: true }));
    await assertFails(setDoc(doc(db(USERS.bob), 'users/bob'), profile('bob', { disabled: false })));
    await assertFails(updateDoc(doc(db(USERS.bob), 'users/alice'), { disabled: true }));
    await assertSucceeds(updateDoc(doc(db(ADMIN), 'users/alice'), {
      disabled: true, disabledAt: serverTimestamp(), disabledBy: 'admin',
    }));
    // Yönetici diğer alanlara dokunamaz ve kendini pasife alamaz.
    await assertFails(updateDoc(doc(db(ADMIN), 'users/alice'), { displayName: 'x' }));
    await seed((fs) => setDoc(doc(fs, 'users/admin'), profile('admin', { email: ADMIN.email })));
    await assertFails(updateDoc(doc(db(ADMIN), 'users/admin'), { disabled: true }));
    // Pasif kullanıcı kendi aktiflik durumunu geri açamaz.
    await assertFails(updateDoc(doc(alice, 'users/alice'), { disabled: false }));
  });

  test('pasif kullanıcı verilere erişemez, kendi profilini okuyabilir; aktife alınınca erişir', async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, 'users/alice'), profile('alice', { disabled: true }));
      await setDoc(doc(fs, 'expenses/e1'), expense('e1', 'alice'));
    });
    const alice = db(USERS.alice);
    await assertFails(getDoc(doc(alice, 'expenses/e1')));
    await assertFails(setDoc(doc(alice, 'expenses/e2'), expense('e2', 'alice')));
    await assertFails(getDocs(query(collection(alice, 'expenses'), where('ownerUid', '==', 'alice'))));
    await assertSucceeds(getDoc(doc(alice, 'users/alice')));
    await assertSucceeds(updateDoc(doc(db(ADMIN), 'users/alice'), { disabled: false, disabledAt: null, disabledBy: null }));
    await assertSucceeds(getDoc(doc(alice, 'expenses/e1')));
  });

  test('öneriyi kullanıcı kendi adına ekler; yalnızca yönetici okur ve okundu yapar', async () => {
    const alice = db(USERS.alice);
    await assertSucceeds(setDoc(doc(alice, 'feedback/f1'), feedback('f1', 'alice')));
    await assertFails(setDoc(doc(alice, 'feedback/f2'), feedback('f2', 'bob')));
    await assertFails(setDoc(doc(alice, 'feedback/f3'), feedback('f3', 'alice', { status: 'read' })));
    await assertFails(setDoc(doc(alice, 'feedback/f4'), feedback('f4', 'alice', { message: 'x'.repeat(2001) })));
    await assertFails(setDoc(doc(alice, 'feedback/f5'), feedback('f5', 'alice', { extra: true })));
    await assertFails(getDoc(doc(db(USERS.bob), 'feedback/f1')));
    await assertSucceeds(getDoc(doc(db(ADMIN), 'feedback/f1')));
    await assertFails(updateDoc(doc(db(ADMIN), 'feedback/f1'), { message: 'değişti' }));
    await assertSucceeds(updateDoc(doc(db(ADMIN), 'feedback/f1'), { status: 'read' }));
    // Hesap silmede kullanıcı kendi önerilerini bulup siler.
    await assertSucceeds(getDocs(query(collection(alice, 'feedback'), where('uid', '==', 'alice'))));
    await assertFails(getDocs(query(collection(db(USERS.bob), 'feedback'), where('uid', '==', 'alice'))));
    await assertFails(deleteDoc(doc(db(USERS.bob), 'feedback/f1')));
    await assertSucceeds(deleteDoc(doc(alice, 'feedback/f1')));
  });

  test('sürüm notlarını herkes okur, yalnızca yönetici yazar', async () => {
    await assertSucceeds(setDoc(doc(db(ADMIN), 'releaseNotes/1.2.0'), notes('1.2.0')));
    await assertFails(setDoc(doc(db(ADMIN), 'releaseNotes/1.2'), notes('1.2')));
    await assertFails(setDoc(doc(db(ADMIN), 'releaseNotes/1.3.0'), notes('1.3.0', { addedTr: Array(21).fill('x') })));
    await assertFails(setDoc(doc(db(USERS.alice), 'releaseNotes/1.2.0'), notes('1.2.0')));
    await assertSucceeds(getDoc(doc(db(USERS.alice), 'releaseNotes/1.2.0')));
  });
});

describe('Yönetim paneli yetkisi', () => {
  const ADMIN = { uid: 'admin', email: 'hasancaktar@gmail.com' };
  const category = (id, o = {}) => ({
    id, nameTr: 'Evcil hayvan', nameEn: 'Pets', iconKey: 'pets', colorHex: '#10B981',
    isActive: true, isDeleted: false, order: 3, ...o,
  });
  const campaign = (id, by, o = {}) => ({
    id, type: 'manual', status: 'queued', createdBy: by, createdByEmail: 'x', titleTr: 'Duyuru', bodyTr: 'Merhaba',
    titleEn: '', bodyEn: '', target: 'all', targetUids: [], createdAt: serverTimestamp(), ...o,
  });
  const reminder = (o = {}) => ({
    enabled: true, hour: 21, minute: 0, titleTr: 'Harcama Takip', bodyTr: 'Unutmayın', titleEn: '', bodyEn: '',
    target: 'all', targetUids: [], timezone: 'Europe/Istanbul', ...o,
  });
  const log = (by) => ({
    id: 'l', action: 'category.create', summary: 'x', adminUid: by, adminEmail: 'x', createdAt: serverTimestamp(),
  });

  test('kategorileri herkes okur, yalnızca yönetici yazar; belge silinemez', async () => {
    await assertSucceeds(setDoc(doc(db(ADMIN), 'categories/pets'), category('pets')));
    await assertSucceeds(getDocs(collection(db(USERS.alice), 'categories')));
    await assertFails(setDoc(doc(db(USERS.alice), 'categories/hack'), category('hack')));
    await assertFails(updateDoc(doc(db(USERS.alice), 'categories/pets'), { nameTr: 'x' }));
    await assertFails(deleteDoc(doc(db(ADMIN), 'categories/pets')));
    await assertSucceeds(updateDoc(doc(db(ADMIN), 'categories/pets'), { isDeleted: true }));
    await assertFails(setDoc(doc(db(ADMIN), 'categories/bad'), category('bad', { colorHex: 'red' })));
    await assertFails(getDocs(collection(db(USERS.alice, { verified: false }), 'categories')));
  });

  test('yönetici e-postası doğrulanmamışsa yetkisi yoktur', async () => {
    await assertFails(setDoc(doc(db(ADMIN, { verified: false }), 'categories/pets'), category('pets')));
  });

  test('benzer e-postalı farklı hesap yönetici sayılmaz', async () => {
    const fake = { uid: 'fake', email: 'hasancaktar@gmail.com.evil.test' };
    await assertFails(setDoc(doc(db(fake), 'categories/pets'), category('pets')));
  });

  test('bildirimi yalnızca yönetici kuyruğa ekler; sonuç alanları istemciden yazılamaz', async () => {
    await assertSucceeds(setDoc(doc(db(ADMIN), 'notificationCampaigns/c1'), campaign('c1', 'admin')));
    await assertFails(setDoc(doc(db(USERS.alice), 'notificationCampaigns/c2'), campaign('c2', 'alice')));
    await assertFails(getDoc(doc(db(USERS.alice), 'notificationCampaigns/c1')));
    await assertFails(setDoc(doc(db(ADMIN), 'notificationCampaigns/c3'), campaign('c3', 'admin', { status: 'sent' })));
    await assertFails(setDoc(doc(db(ADMIN), 'notificationCampaigns/c4'),
      campaign('c4', 'admin', { target: 'selected', targetUids: [] })));
    await assertFails(updateDoc(doc(db(ADMIN), 'notificationCampaigns/c1'), { status: 'sent' }));
    await assertFails(deleteDoc(doc(db(ADMIN), 'notificationCampaigns/c1')));
  });

  test('günlük hatırlatma ayarını yalnızca yönetici okur/yazar; lastSentDate değiştirilemez', async () => {
    await assertSucceeds(setDoc(doc(db(ADMIN), 'appConfig/dailyReminder'), reminder()));
    await assertFails(getDoc(doc(db(USERS.alice), 'appConfig/dailyReminder')));
    await assertFails(setDoc(doc(db(USERS.alice), 'appConfig/dailyReminder'), reminder()));
    await assertFails(setDoc(doc(db(ADMIN), 'appConfig/dailyReminder'), reminder({ hour: 25 })));
    await assertFails(setDoc(doc(db(ADMIN), 'appConfig/dailyReminder'),
      reminder({ lastSentDate: '2020-01-01' }), { merge: true }));
    await assertFails(setDoc(doc(db(ADMIN), 'appConfig/other'), reminder()));
  });

  test('işlem kayıtları yalnızca eklenir; değiştirilemez, silinemez, kullanıcılar okuyamaz', async () => {
    await assertSucceeds(setDoc(doc(db(ADMIN), 'adminLogs/l'), log('admin')));
    await assertFails(updateDoc(doc(db(ADMIN), 'adminLogs/l'), { summary: 'değişti' }));
    await assertFails(deleteDoc(doc(db(ADMIN), 'adminLogs/l')));
    await assertFails(getDoc(doc(db(USERS.alice), 'adminLogs/l')));
    await assertFails(setDoc(doc(db(USERS.alice), 'adminLogs/l2'), log('alice')));
  });

  test('yönetici kullanıcı listesini okur; normal kullanıcı okuyamaz', async () => {
    await seed((fs) => setDoc(doc(fs, 'users/alice'), { uid: 'alice', email: USERS.alice.email, displayName: 'Alice' }));
    await assertSucceeds(getDocs(collection(db(ADMIN), 'users')));
    await assertFails(getDocs(collection(db(USERS.bob), 'users')));
    // Yönetici başkasının profilini değiştiremez.
    await assertFails(updateDoc(doc(db(ADMIN), 'users/alice'), { displayName: 'x' }));
  });

  test('kullanıcı bildirim tercihini ve dilini güncelleyebilir', async () => {
    await seed((fs) => setDoc(doc(fs, 'users/alice'), { uid: 'alice', email: USERS.alice.email, displayName: 'Alice' }));
    await assertSucceeds(updateDoc(doc(db(USERS.alice), 'users/alice'), { pushEnabled: false, language: 'en' }));
    await assertFails(updateDoc(doc(db(USERS.alice), 'users/alice'), { language: 'xx' }));
  });
});

describe('Taksit planları', () => {
  const plan = (id, owner, overrides = {}) => ({
    id, ownerUid: owner, teamId: null, visibility: 'personal', title: 'Telefon',
    totalAmountInCents: 3000000, totalInstallments: 2, cardId: 'c1', cardLast4: '1234', category: 'shopping',
    startDate: now(), currency: 'TRY', status: 'active', createdAt: now(), updatedAt: now(),
    installmentSchedule: [
      { installmentNumber: 1, amountInCents: 1500000, statementPeriod: '2026-11', statementCutoffDate: now(), dueDate: now(), status: 'posted' },
      { installmentNumber: 2, amountInCents: 1500000, statementPeriod: '2026-12', statementCutoffDate: now(), dueDate: now(), status: 'upcoming' },
    ],
    ...overrides,
  });

  test('plan ve ilk taksit harcaması aynı yığında yazılabilir', async () => {
    const fs = db(USERS.alice);
    const batch = writeBatch(fs);
    batch.set(doc(fs, 'installmentPlans/p1'), plan('p1', 'alice'));
    batch.set(doc(fs, 'expenses/p1_1_2026-11'), expense('p1_1_2026-11', 'alice', {
      isInstallment: true, installmentPlanId: 'p1', paymentMethod: 'credit_card', cardId: 'c1', cardLast4: '1234',
    }));
    await assertSucceeds(batch.commit());
  });

  test('başkasının planı iptal edilemez; taksit sayısı tutarsız plan reddedilir', async () => {
    await seed((fs) => setDoc(doc(fs, 'installmentPlans/p1'), plan('p1', 'alice')));
    await assertFails(updateDoc(doc(db(USERS.eve), 'installmentPlans/p1'), { status: 'cancelled' }));
    await assertSucceeds(updateDoc(doc(db(USERS.alice), 'installmentPlans/p1'), { status: 'cancelled', updatedAt: now() }));
    await assertFails(setDoc(doc(db(USERS.alice), 'installmentPlans/p2'), plan('p2', 'alice', { totalInstallments: 5 })));
  });

  test('iptal: plan ve gelecek ayın taksit harcaması aynı yığında güncellenir', async () => {
    const installment = (n, period) => expense(`p1_${n}_${period}`, 'alice', {
      isInstallment: true, installmentPlanId: 'p1', paymentMethod: 'credit_card',
      cardId: 'c1', cardLast4: '1234', statementPeriod: period,
    });
    await seed(async (fs) => {
      await setDoc(doc(fs, 'installmentPlans/p1'), plan('p1', 'alice'));
      await setDoc(doc(fs, 'expenses/p1_1_2026-11'), installment(1, '2026-11'));
      await setDoc(doc(fs, 'expenses/p1_2_2026-12'), installment(2, '2026-12'));
    });
    const softDelete = { status: 'deleted', deletedAt: now(), deletedBy: 'alice', updatedAt: now() };

    // Başkası iptal yığınını yazamaz.
    const eve = db(USERS.eve);
    const evil = writeBatch(eve);
    evil.update(doc(eve, 'expenses/p1_2_2026-12'), { ...softDelete, deletedBy: 'eve' });
    evil.update(doc(eve, 'installmentPlans/p1'), { status: 'cancelled', updatedAt: now() });
    await assertFails(evil.commit());

    const fs = db(USERS.alice);
    const batch = writeBatch(fs);
    batch.update(doc(fs, 'expenses/p1_2_2026-12'), softDelete);
    batch.update(doc(fs, 'installmentPlans/p1'), {
      status: 'cancelled',
      installmentSchedule: plan('p1', 'alice').installmentSchedule,
      updatedAt: now(),
    });
    await assertSucceeds(batch.commit());
  });
});

describe('Takım üyesi görünen adı', () => {
  test('üye yalnızca kendi kaydındaki adı değiştirebilir', async () => {
    await seedTeam();
    await assertSucceeds(updateDoc(doc(db(USERS.bob), 'teams/t1/members/bob'), { displayName: 'Bob Yılmaz' }));
    // Başka bir üyenin adı değiştirilemez.
    await assertFails(updateDoc(doc(db(USERS.bob), 'teams/t1/members/alice'), { displayName: 'Hacked' }));
    // Ad dışında alan (ör. rol) değiştirilemez.
    await assertFails(updateDoc(doc(db(USERS.bob), 'teams/t1/members/bob'), { role: 'owner' }));
    await assertFails(updateDoc(doc(db(USERS.bob), 'teams/t1/members/bob'), { displayName: 'x'.repeat(81) }));
    // E-postası doğrulanmamış hesap güncelleyemez.
    await assertFails(updateDoc(doc(db(USERS.bob, { verified: false }), 'teams/t1/members/bob'), { displayName: 'Bob' }));
  });
});

describe('Yakıt takibi', () => {
  const fuel = (overrides = {}) => ({
    type: 'gasoline',
    liters: 36.58,
    pricePerLiterCents: 6669,
    vehicleId: 'v1',
    vehicleName: 'Egea Cross',
    odometerKm: 85150,
    fullTank: true,
    ...overrides,
  });
  const fuelExpense = (id, owner, fuelOverrides = {}, overrides = {}) =>
    expense(id, owner, { category: 'fuel', amountInCents: 243952, fuel: fuel(fuelOverrides), ...overrides });

  function vehicle(id, owner, overrides = {}) {
    return {
      id,
      ownerUid: owner,
      name: 'Egea Cross',
      brand: 'Fiat',
      fuelType: 'gasoline',
      odometerKm: 85000,
      createdAt: now(),
      updatedAt: now(),
      ...overrides,
    };
  }

  test('akaryakıt harcaması yakıt bilgileriyle kaydedilir; tam sayı litre de kabul edilir', async () => {
    const fs = db(USERS.alice);
    await assertSucceeds(setDoc(doc(fs, 'expenses/f1'), fuelExpense('f1', 'alice')));
    await assertSucceeds(setDoc(doc(fs, 'expenses/f2'), fuelExpense('f2', 'alice', { liters: 40, odometerKm: null, vehicleId: null, vehicleName: null })));
    await assertSucceeds(updateDoc(doc(fs, 'expenses/f1'), { 'fuel.fullTank': false, updatedAt: now() }));
    // Yakıt bilgisi olmayan eski kayıtlar da geçerlidir.
    await assertSucceeds(setDoc(doc(fs, 'expenses/f3'), expense('f3', 'alice', { category: 'fuel', fuel: null })));
  });

  test('geçersiz yakıt bilgileri reddedilir', async () => {
    const fs = db(USERS.alice);
    await assertFails(setDoc(doc(fs, 'expenses/a'), fuelExpense('a', 'alice', { type: 'kerosene' })));
    await assertFails(setDoc(doc(fs, 'expenses/b'), fuelExpense('b', 'alice', { liters: 0 })));
    await assertFails(setDoc(doc(fs, 'expenses/c'), fuelExpense('c', 'alice', { liters: 5001 })));
    await assertFails(setDoc(doc(fs, 'expenses/d'), fuelExpense('d', 'alice', { pricePerLiterCents: 66.69 })));
    await assertFails(setDoc(doc(fs, 'expenses/e'), fuelExpense('e', 'alice', { pricePerLiterCents: 100001 })));
    await assertFails(setDoc(doc(fs, 'expenses/f'), fuelExpense('f', 'alice', { odometerKm: -1 })));
    await assertFails(setDoc(doc(fs, 'expenses/g'), fuelExpense('g', 'alice', { vehicleName: 'x'.repeat(41) })));
    await assertFails(setDoc(doc(fs, 'expenses/h'), fuelExpense('h', 'alice', { fullTank: 'evet' })));
    await assertFails(setDoc(doc(fs, 'expenses/i'), fuelExpense('i', 'alice', { plate: '34 ABC 123' })));
    await assertFails(setDoc(doc(fs, 'expenses/j'), expense('j', 'alice', { category: 'fuel', fuel: 'benzin' })));
  });

  test('yakıt özeti sorgusu yalnızca kendi kayıtları için izinlidir', async () => {
    const alice = db(USERS.alice);
    await assertSucceeds(getDocs(query(
      collection(alice, 'expenses'),
      where('ownerUid', '==', 'alice'),
      where('category', '==', 'fuel'),
      where('status', '==', 'active'),
    )));
    await assertFails(getDocs(query(
      collection(alice, 'expenses'),
      where('ownerUid', '==', 'bob'),
      where('category', '==', 'fuel'),
      where('status', '==', 'active'),
    )));
  });

  test('araçlar yalnızca sahibine açıktır', async () => {
    const alice = db(USERS.alice);
    await assertSucceeds(setDoc(doc(alice, 'vehicles/v1'), vehicle('v1', 'alice')));
    await assertSucceeds(setDoc(doc(alice, 'vehicles/v2'), vehicle('v2', 'alice', { brand: null, odometerKm: null, fuelType: 'lpg' })));
    await assertSucceeds(updateDoc(doc(alice, 'vehicles/v1'), { name: 'Egea', updatedAt: now() }));
    await assertSucceeds(getDocs(query(collection(alice, 'vehicles'), where('ownerUid', '==', 'alice'))));
    await assertFails(getDocs(collection(alice, 'vehicles')));

    const eve = db(USERS.eve);
    await assertFails(getDoc(doc(eve, 'vehicles/v1')));
    await assertFails(updateDoc(doc(eve, 'vehicles/v1'), { name: 'Benim' }));
    await assertFails(deleteDoc(doc(eve, 'vehicles/v1')));
    await assertFails(setDoc(doc(eve, 'vehicles/v9'), vehicle('v9', 'alice')));
    await assertFails(getDocs(query(collection(eve, 'vehicles'), where('ownerUid', '==', 'alice'))));
    // Sahiplik devredilemez.
    await assertFails(updateDoc(doc(alice, 'vehicles/v1'), { ownerUid: 'eve' }));

    await assertSucceeds(deleteDoc(doc(alice, 'vehicles/v2')));
    // E-postası doğrulanmamış hesap araç ekleyemez.
    await assertFails(setDoc(doc(db(USERS.alice, { verified: false }), 'vehicles/v3'), vehicle('v3', 'alice')));
  });

  test('geçersiz araç kayıtları reddedilir', async () => {
    const alice = db(USERS.alice);
    await assertFails(setDoc(doc(alice, 'vehicles/a'), vehicle('a', 'alice', { name: '' })));
    await assertFails(setDoc(doc(alice, 'vehicles/b'), vehicle('b', 'alice', { name: 'x'.repeat(41) })));
    await assertFails(setDoc(doc(alice, 'vehicles/c'), vehicle('c', 'alice', { fuelType: 'electric' })));
    await assertFails(setDoc(doc(alice, 'vehicles/d'), vehicle('d', 'alice', { odometerKm: 10000000 })));
    await assertFails(setDoc(doc(alice, 'vehicles/e'), vehicle('e', 'alice', { plate: '34 ABC 123' })));
    await assertFails(setDoc(doc(alice, 'vehicles/f'), vehicle('wrong-id', 'alice')));
  });
});

describe('Banka kartları', () => {
  function debitCard(id, owner, overrides = {}) {
    return {
      id,
      ownerUid: owner,
      name: 'Bankkart',
      bankName: 'Ziraat Bankası',
      last4Digits: '4321',
      colorHex: '#0F766E',
      isActive: true,
      createdAt: now(),
      updatedAt: now(),
      ...overrides,
    };
  }

  test('banka kartı yalnızca sahibine açıktır; kaldırılabilir', async () => {
    const alice = db(USERS.alice);
    await assertSucceeds(setDoc(doc(alice, 'debitCards/d1'), debitCard('d1', 'alice')));
    await assertSucceeds(getDocs(query(
      collection(alice, 'debitCards'),
      where('ownerUid', '==', 'alice'),
      where('isActive', '==', true),
    )));
    await assertSucceeds(updateDoc(doc(alice, 'debitCards/d1'), { isActive: false, updatedAt: now() }));
    await assertFails(getDocs(collection(alice, 'debitCards')));

    const eve = db(USERS.eve);
    await assertFails(getDoc(doc(eve, 'debitCards/d1')));
    await assertFails(updateDoc(doc(eve, 'debitCards/d1'), { name: 'Benim' }));
    await assertFails(deleteDoc(doc(eve, 'debitCards/d1')));
    await assertFails(setDoc(doc(eve, 'debitCards/d9'), debitCard('d9', 'alice')));
    await assertFails(updateDoc(doc(alice, 'debitCards/d1'), { ownerUid: 'eve' }));
    await assertFails(setDoc(doc(db(USERS.alice, { verified: false }), 'debitCards/d2'), debitCard('d2', 'alice')));
  });

  test('geçersiz banka kartı reddedilir; kart numarası saklanamaz', async () => {
    const alice = db(USERS.alice);
    await assertFails(setDoc(doc(alice, 'debitCards/a'), debitCard('a', 'alice', { last4Digits: '12345' })));
    await assertFails(setDoc(doc(alice, 'debitCards/b'), debitCard('b', 'alice', { name: '' })));
    await assertFails(setDoc(doc(alice, 'debitCards/c'), debitCard('c', 'alice', { cardNumber: '4111111111111111' })));
    await assertFails(setDoc(doc(alice, 'debitCards/d'), debitCard('wrong', 'alice')));
  });

  test('banka kartıyla ödenen harcama kart bilgisiyle kaydedilir', async () => {
    const fs = db(USERS.alice);
    await assertSucceeds(setDoc(doc(fs, 'expenses/x1'), expense('x1', 'alice', {
      paymentMethod: 'debit_card', cardId: 'd1', cardLast4: '4321',
    })));
  });
});
