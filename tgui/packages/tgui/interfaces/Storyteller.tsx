import React, { useMemo, useState } from 'react';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Stack,
  Table,
  Tabs,
  TextArea,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

/* ============================
 * Types
 * ============================ */

type Candidate = {
  id: string;
  name: string;
  type: 'event' | 'ruleset' | 'latejoin';
  score: number;
  weight: number;
  impact: number;
  dept: string;
  tags: string[] | string;
  on_cd?: boolean;
  cd_left?: number;
};

type DepartmentRow = {
  players?: number;
  count?: number;
  avg_exp?: number;
};

type Departments = Record<string, DepartmentRow>;

type ProfileDTO = {
  id?: string;
  name?: string;
  description?: string;
  attention_tags?: string[];
  ignore_tags?: string[];
  preferred_targets?: string[];
  selectable?: boolean;
  frequency?: number;
  allow_auto?: boolean;
  deadband?: number;
  min_gap_sec?: number;
  drop_shape?: number;
  allow_force_pick?: boolean;
  assist_window?: number;
  assist_prob?: number;
  dept_weight?: number;
  phase_plan?: any[];
};

type ProfilesMap = Record<string, ProfileDTO>;

type PhaseInfo = {
  index?: number;
  title?: string;
  description?: string;
  duration_min?: number;
  pool_count?: number;
};

type ChaosBreakItem = { name: string; value: number };

type GlobalsDTO = {
  llm_enabled?: boolean;
  local_enabled?: boolean;
  smooth_window_sec?: number;
  cooldown_default_sec?: number;
};

type Data = {
  inactive?: boolean;

  profile?: ProfileDTO;
  profiles?: ProfilesMap;

  chaos?: { raw: number; smooth: number };
  chaos_breakdown?: ChaosBreakItem[];

  target?: { target_final: number; current: number; budget: number };

  metrics?: {
    players_total?: number;
    players_alive?: number;
    deaths_recent?: number;
    air_alarms?: number;
    violence?: number;
    credits_total?: number;
    antags?: number;
    events_known?: number;
    custom_goals?: number;
  };

  departments?: Departments;
  scored?: Candidate[];
  history?: any[];

  raw_state?: any;
  cached_state?: any;

  phase_plan?: any[];
  phase?: PhaseInfo;
  phase_total?: number;

  globals?: GlobalsDTO;
};

/* ============================
 * Utils & small shared parts
 * ============================ */

const FixedScroll: React.FC<
  React.PropsWithChildren<{ h?: string; px?: number }>
> = ({ h = '14rem', px = 0, children }) => (
  <Box style={{ maxHeight: h, overflow: 'auto' }} px={px}>
    {children}
  </Box>
);

const ticksToSec = (ticks?: number) =>
  `${Math.floor(Number(ticks || 0) / 10)}s`;

const summarizeHistoryRow = (row: any) => {
  const id = row?.id ?? row?.event_id ?? row?.ruleset ?? '—';
  const type = row?.type ?? '—';
  const budget =
    typeof row?.budget === 'number'
      ? String(Math.round(row.budget * 10) / 10)
      : (row?.budget ?? '—');
  const details: any = { ...(row || {}) };
  delete details.ts;
  delete details.kind;
  delete details.id;
  delete details.event_id;
  delete details.ruleset;
  delete details.type;
  delete details.budget;
  return { id, type, budget, details };
};

/* ============================
 * Small components
 * ============================ */

const ProfileCard: React.FC<{
  profId: string;
  p: ProfileDTO;
  active: boolean;
  onUse: () => void;
}> = ({ profId, p, active, onUse }) => (
  <Section
    title={p?.name || profId}
    buttons={
      <Button icon="check" selected={active} onClick={onUse}>
        Use
      </Button>
    }
    style={{ width: '22rem', minWidth: '22rem', height: '18rem' }}
  >
    <Box color="label" mb={0.5} style={{ height: '3.5rem', overflow: 'auto' }}>
      {p?.description || '—'}
    </Box>
    <LabeledList>
      <LabeledList.Item label="Frequency">
        {p?.frequency ?? '—'} s
      </LabeledList.Item>
      <LabeledList.Item label="Deadband">{p?.deadband ?? '—'}</LabeledList.Item>
      <LabeledList.Item label="Gap, s">
        {p?.min_gap_sec ?? '—'}
      </LabeledList.Item>
      <LabeledList.Item label="Assist (win/prob)">
        {p?.assist_window ?? '—'}/{p?.assist_prob ?? '—'}
      </LabeledList.Item>
      <LabeledList.Item label="Dept weight">
        {p?.dept_weight ?? '—'}
      </LabeledList.Item>
      <LabeledList.Item label="Focus tags">
        {Array.isArray(p?.attention_tags) && p.attention_tags.length
          ? p.attention_tags.join(', ')
          : '—'}
      </LabeledList.Item>
      <LabeledList.Item label="Ignore tags">
        {Array.isArray(p?.ignore_tags) && p.ignore_tags.length
          ? p.ignore_tags.join(', ')
          : '—'}
      </LabeledList.Item>
    </LabeledList>
  </Section>
);

const TopBar: React.FC<{
  title: string;
  tab: string;
  setTab: (t: 'metrics' | 'settings' | 'debug') => void;
  act: (action: string, params?: any) => void;
}> = ({ title, tab, setTab, act }) => (
  <Section
    title={title}
    buttons={
      <>
        <Button icon="sync" onClick={() => act('refresh')}>
          Refresh
        </Button>
        <Button icon="bolt" onClick={() => act('pulse_local')}>
          Pulse (Local)
        </Button>
        <Button icon="robot" onClick={() => act('pulse_llm')}>
          Pulse (LLM)
        </Button>
        <Button icon="flag-checkered" onClick={() => act('finalize_end')}>
          Finalize Round
        </Button>
      </>
    }
  >
    <Tabs>
      <Tabs.Tab selected={tab === 'metrics'} onClick={() => setTab('metrics')}>
        Metrics
      </Tabs.Tab>
      <Tabs.Tab
        selected={tab === 'settings'}
        onClick={() => setTab('settings')}
      >
        Settings
      </Tabs.Tab>
      <Tabs.Tab selected={tab === 'debug'} onClick={() => setTab('debug')}>
        Debug
      </Tabs.Tab>
    </Tabs>
  </Section>
);

/* ============================
 * Tabs
 * ============================ */

const MetricsTab: React.FC<{
  data: Data;
  act: (action: string, params?: any) => void;
}> = ({ data, act }) => {
  const profile = data.profile || {};
  const chaos = data.chaos || { raw: 0, smooth: 0 };
  const target = data.target || { target_final: 0, current: 0, budget: 0 };

  const budget = Math.round((target.budget || 0) * 10) / 10;
  const chaosPct = Math.min(100, Math.max(0, chaos.smooth || 0));
  const targetPct = Math.min(100, Math.max(0, target.target_final || 0));

  const profiles = data.profiles || {};
  const departments = data.departments || {};
  const scored = data.scored || [];
  const chaosBreakdown = data.chaos_breakdown || [];

  const selectableProfiles = useMemo(
    () =>
      Object.entries(profiles).filter(
        ([, p]) => (p?.selectable ?? true) !== false,
      ),
    [profiles],
  );

  const [showCandidates, setShowCandidates] = useState(true);
  const [showHistory, setShowHistory] = useState(false);

  const metricCells = [
    {
      label: 'Players (alive/total)',
      value: `${data.metrics?.players_alive ?? 0} / ${data.metrics?.players_total ?? 0}`,
    },
    { label: 'Antags', value: `${data.metrics?.antags ?? 0}` },
    { label: 'Deaths (recent)', value: `${data.metrics?.deaths_recent ?? 0}` },
    { label: 'Air alarms', value: `${data.metrics?.air_alarms ?? 0}` },
    { label: 'Violence score', value: `${data.metrics?.violence ?? 0}` },
    { label: 'Station credits', value: `${data.metrics?.credits_total ?? 0}` },
    { label: 'Events known', value: `${data.metrics?.events_known ?? 0}` },
    { label: 'Custom goals', value: `${data.metrics?.custom_goals ?? 0}` },
    { label: 'Budget', value: budget >= 0 ? `+${budget}` : `${budget}` },
  ];

  const rows3 = [
    metricCells.slice(0, 3),
    metricCells.slice(3, 6),
    metricCells.slice(6, 9),
  ];
  return (
    <>
      <Section title="Chaos">
        <Stack align="start">
          <Stack.Item grow>
            <LabeledList>
              <LabeledList.Item label="Chaos (smooth)">
                <ProgressBar value={chaosPct} maxValue={100}>
                  {chaosPct}%
                </ProgressBar>
                <Box mt={0.5} color="label">
                  raw: {Math.round(chaos.raw || 0)}
                </Box>
              </LabeledList.Item>
              <LabeledList.Item label="Target">
                <ProgressBar value={targetPct} maxValue={100}>
                  {targetPct}%
                </ProgressBar>
                <Box mt={0.5} color={budget >= 0 ? 'good' : 'average'}>
                  Budget: {budget >= 0 ? `+${budget}` : `${budget}`}
                </Box>
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>

          <Stack.Item basis="48%">
            <Table>
              {rows3.map((row, i) => (
                <Table.Row key={i}>
                  {row.map((cell, j) => (
                    <Table.Cell key={j}>
                      <Box color="label" mb={0.25}>
                        {cell.label}
                      </Box>
                      <Box>{cell.value}</Box>
                    </Table.Cell>
                  ))}
                </Table.Row>
              ))}
            </Table>
          </Stack.Item>
        </Stack>
      </Section>

      <Section
        title="Available candidates"
        buttons={
          <Button
            icon={showCandidates ? 'angle-up' : 'angle-down'}
            onClick={() => setShowCandidates((v) => !v)}
          >
            {showCandidates ? 'Hide' : 'Show'}
          </Button>
        }
      >
        {showCandidates ? (
          <FixedScroll h="18rem">
            <Table>
              <Table.Row header>
                <Table.Cell>Score</Table.Cell>
                <Table.Cell>Name</Table.Cell>
                <Table.Cell>Type</Table.Cell>
                <Table.Cell>Impact</Table.Cell>
                <Table.Cell>Weight</Table.Cell>
                <Table.Cell>Dept</Table.Cell>
                <Table.Cell>Tags</Table.Cell>
                <Table.Cell collapsing>CD</Table.Cell>
                <Table.Cell collapsing>Action</Table.Cell>
              </Table.Row>
              {scored.map((c) => (
                <Table.Row key={`${c.id}-${c.type}`}>
                  <Table.Cell bold>{c.score}</Table.Cell>
                  <Table.Cell>{c.name}</Table.Cell>
                  <Table.Cell>{c.type}</Table.Cell>
                  <Table.Cell>{c.impact}</Table.Cell>
                  <Table.Cell>{c.weight}</Table.Cell>
                  <Table.Cell>{c.dept || '-'}</Table.Cell>
                  <Table.Cell>
                    {Array.isArray(c.tags) ? c.tags.join(', ') : c.tags}
                  </Table.Cell>
                  <Table.Cell collapsing>
                    {c.on_cd ? `${c.cd_left || 0} ds` : '—'}
                  </Table.Cell>
                  <Table.Cell collapsing>
                    <Button
                      icon="play"
                      disabled={!!c.on_cd}
                      tooltip={c.on_cd ? 'On cooldown' : undefined}
                      onClick={() => act('trigger', { id: c.id, type: c.type })}
                    >
                      Trigger
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          </FixedScroll>
        ) : (
          <Box color="label">Скрыто</Box>
        )}
      </Section>

      <Section
        title="History"
        buttons={
          <Button
            icon={showHistory ? 'angle-up' : 'angle-down'}
            onClick={() => setShowHistory((v) => !v)}
          >
            {showHistory ? 'Hide' : 'Show'}
          </Button>
        }
      >
        {showHistory ? (
          <FixedScroll h="14rem">
            <Table>
              <Table.Row header>
                <Table.Cell collapsing>Time</Table.Cell>
                <Table.Cell collapsing>Kind</Table.Cell>
                <Table.Cell>Id</Table.Cell>
                <Table.Cell collapsing>Type</Table.Cell>
                <Table.Cell collapsing>Budget</Table.Cell>
                <Table.Cell>Details</Table.Cell>
              </Table.Row>
              {(data.history || []).map((h, i) => {
                const time = ticksToSec(h?.ts);
                const kind = h?.kind ?? '—';
                const { id, type, budget, details } = summarizeHistoryRow(h);
                return (
                  <Table.Row key={`${i}-${h?.ts || 0}`}>
                    <Table.Cell collapsing>{time}</Table.Cell>
                    <Table.Cell collapsing>{kind}</Table.Cell>
                    <Table.Cell>{id}</Table.Cell>
                    <Table.Cell collapsing>{type}</Table.Cell>
                    <Table.Cell collapsing>{budget}</Table.Cell>
                    <Table.Cell>
                      <Box style={{ whiteSpace: 'pre-wrap' }}>
                        {Object.keys(details || {}).length
                          ? JSON.stringify(details)
                          : '—'}
                      </Box>
                    </Table.Cell>
                  </Table.Row>
                );
              })}
            </Table>
          </FixedScroll>
        ) : (
          <Box color="label">Скрыто</Box>
        )}
      </Section>

      <Section title="Departments">
        <FixedScroll h="14rem">
          <Table>
            <Table.Row header>
              <Table.Cell>Department</Table.Cell>
              <Table.Cell collapsing align="right">
                Players
              </Table.Cell>
              <Table.Cell collapsing>Avg. EXP</Table.Cell>
            </Table.Row>
            {Object.entries(departments).map(([name, v]) => {
              const cnt = (v as any)?.players ?? (v as any)?.count ?? 0;
              const avgExp = Math.max(
                0,
                Math.min(1, Number((v as any)?.avg_exp ?? 0)),
              );
              return (
                <Table.Row key={name}>
                  <Table.Cell bold>{name}</Table.Cell>
                  <Table.Cell align="right">{cnt}</Table.Cell>
                  <Table.Cell collapsing width="20rem">
                    <ProgressBar value={avgExp} maxValue={1}>
                      {(avgExp * 100) | 0}%
                    </ProgressBar>
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table>
        </FixedScroll>
      </Section>
    </>
  );
};

type PhaseRow = {
  title?: string;
  description?: string;
  duration_min?: number;
  pool?: string[]; // список id
};

const PhasePlanEditor: React.FC<{
  plan: PhaseRow[];
  act: (action: string, params?: any) => void;
  catalog?: {
    events?: Record<string, string>;
    rulesets?: Record<string, string>;
  }; // опционально
}> = ({ plan, act, catalog }) => {
  // локальные поля для добавления ID в пул (по одному инпуту на фазу)
  const [addInputs, setAddInputs] = React.useState<Record<number, string>>({});

  const getName = (id: string) => {
    const nm =
      (catalog?.events && catalog.events[id]) ||
      (catalog?.rulesets && catalog.rulesets[id]);
    return nm ? `${id} — ${nm}` : id;
  };

  return (
    <Section
      title={`Phase plan — ${plan?.length || 0} phases`}
      buttons={
        <Button icon="plus" onClick={() => act('phase_add')}>
          Add phase
        </Button>
      }
    >
      {(!Array.isArray(plan) || plan.length === 0) && (
        <Box color="label">No phases yet.</Box>
      )}

      {Array.isArray(plan) &&
        plan.map((ph, i) => {
          const idx = i + 1;
          const pool = Array.isArray(ph?.pool) ? (ph.pool as string[]) : [];
          const addVal = addInputs[idx] || '';

          return (
            <Section
              key={`phase-${idx}`}
              title={`#${idx} — ${ph?.title || 'Untitled phase'}`}
              buttons={
                <>
                  <Button
                    icon="arrow-up"
                    disabled={i === 0}
                    tooltip="Move up"
                    onClick={() =>
                      act('phase_reorder', { index: idx, new_index: i })
                    }
                  />
                  <Button
                    icon="arrow-down"
                    disabled={i === plan.length - 1}
                    tooltip="Move down"
                    onClick={() =>
                      act('phase_reorder', { index: idx, new_index: i + 2 })
                    }
                  />
                  <Button.Confirm
                    icon="trash"
                    color="bad"
                    tooltip="Delete phase"
                    onClick={() => act('phase_delete', { index: idx })}
                  >
                    Delete
                  </Button.Confirm>
                </>
              }
            >
              {/* Основные поля фазы */}
              <Stack>
                <Stack.Item grow>
                  <LabeledList>
                    <LabeledList.Item label="Title">
                      <TextArea
                        value={ph?.title || ''}
                        onChange={(v: string) =>
                          act('phase_update', {
                            index: idx,
                            changes: { title: v },
                          })
                        }
                      />
                    </LabeledList.Item>

                    <LabeledList.Item label="Description">
                      <TextArea
                        value={ph?.description || ''}
                        onChange={(v: string) =>
                          act('phase_update', {
                            index: idx,
                            changes: { description: v },
                          })
                        }
                      />
                    </LabeledList.Item>
                  </LabeledList>
                </Stack.Item>

                <Stack.Item basis="20rem">
                  <LabeledList>
                    <LabeledList.Item label="Duration (min)">
                      <NumberInput
                        value={ph?.duration_min ?? 0}
                        minValue={0}
                        maxValue={180}
                        step={5}
                        onChange={(v) =>
                          act('phase_update', {
                            index: idx,
                            changes: { duration_min: v },
                          })
                        }
                      />
                    </LabeledList.Item>
                    <LabeledList.Item label="Pool size">
                      {pool.length}
                    </LabeledList.Item>
                  </LabeledList>
                </Stack.Item>
              </Stack>

              {/* Пул событий/рулсетов */}
              <Section title="Pool">
                {pool.length ? (
                  <FixedScroll h="12rem">
                    <Table>
                      <Table.Row header>
                        <Table.Cell>ID / Name</Table.Cell>
                        <Table.Cell collapsing>Action</Table.Cell>
                      </Table.Row>
                      {pool.map((id) => (
                        <Table.Row key={`${idx}-${id}`}>
                          <Table.Cell>{getName(id)}</Table.Cell>
                          <Table.Cell collapsing>
                            <Button
                              icon="times"
                              tooltip="Remove from pool"
                              onClick={() =>
                                act('phase_pool_remove', { index: idx, id })
                              }
                            />
                          </Table.Cell>
                        </Table.Row>
                      ))}
                    </Table>
                  </FixedScroll>
                ) : (
                  <Box color="label">Pool is empty.</Box>
                )}

                {/* Добавление нового ID в пул */}
                <Stack align="center" mt={1}>
                  <Stack.Item grow>
                    <TextArea
                      placeholder="Paste event/ruleset id (e.g. /datum/round_event_control/meteor_wave/meaty)"
                      value={addVal}
                      onChange={(v: string) =>
                        setAddInputs((s) => ({ ...s, [idx]: v }))
                      }
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="plus"
                      disabled={!addVal?.trim()}
                      onClick={() => {
                        const id = addVal.trim();
                        act('phase_pool_add', { index: idx, id });
                        setAddInputs((s) => ({ ...s, [idx]: '' }));
                      }}
                    >
                      Add to pool
                    </Button>
                  </Stack.Item>
                </Stack>

                {/* Подсказка каталога (если бэк когда-нибудь отдаёт data.catalog) */}
                {catalog &&
                (Object.keys(catalog.events || {}).length ||
                  Object.keys(catalog.rulesets || {}).length) ? (
                  <Box color="label" mt={0.5}>
                    Tip: you can paste an ID from available catalog. (Catalog is
                    optional and may not be loaded here.)
                  </Box>
                ) : null}
              </Section>
            </Section>
          );
        })}
    </Section>
  );
};

const SettingsTab: React.FC<{
  data: Data;
  act: (action: string, params?: any) => void;
}> = ({ data, act }) => {
  const profile = data.profile || {};
  const profiles = data.profiles || {};
  const selectableProfiles = useMemo(
    () =>
      Object.entries(profiles).filter(
        ([, p]) => (p?.selectable ?? true) !== false,
      ),
    [profiles],
  );

  // локальный стейт редактируемых чисел
  const [pf, setPf] = useState<ProfileDTO>({
    frequency: profile.frequency,
    deadband: profile.deadband,
    min_gap_sec: profile.min_gap_sec,
    drop_shape: profile.drop_shape,
    assist_window: profile.assist_window,
    assist_prob: profile.assist_prob,
    allow_force_pick: profile.allow_force_pick,
    dept_weight: profile.dept_weight,
  });

  const [gl, setGl] = useState<GlobalsDTO>({ ...(data.globals || {}) });

  return (
    <>
      {/* Переключение профиля */}
      <Section title="Switch profile">
        <FixedScroll h="20rem" px={1}>
          <Stack wrap>
            {(selectableProfiles.length
              ? Object.fromEntries(selectableProfiles)
              : profiles) &&
              Object.entries(
                selectableProfiles.length
                  ? Object.fromEntries(selectableProfiles)
                  : profiles,
              ).map(([id, p]) => (
                <Stack.Item key={id}>
                  <ProfileCard
                    profId={id}
                    p={p}
                    active={profile.id === id || profile.name === p?.name}
                    onUse={() => act('set_profile', { id })}
                  />
                </Stack.Item>
              ))}
          </Stack>
        </FixedScroll>
      </Section>

      {/* Настройки текущего профиля */}
      <Section title="Current profile settings">
        <Stack>
          <Stack.Item grow>
            <LabeledList>
              <LabeledList.Item label="Frequency (sec)">
                <NumberInput
                  value={pf.frequency ?? 30}
                  minValue={5}
                  maxValue={600}
                  step={5}
                  onChange={(v) => setPf((s) => ({ ...s, frequency: v }))}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Deadband">
                <NumberInput
                  value={pf.deadband ?? 6}
                  minValue={0}
                  maxValue={50}
                  step={1}
                  onChange={(v) => setPf((s) => ({ ...s, deadband: v }))}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Gap (sec)">
                <NumberInput
                  value={pf.min_gap_sec ?? 180}
                  minValue={0}
                  maxValue={900}
                  step={10}
                  onChange={(v) => setPf((s) => ({ ...s, min_gap_sec: v }))}
                />
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>

          <Stack.Item grow>
            <LabeledList>
              <LabeledList.Item label="Drop shape">
                <NumberInput
                  value={pf.drop_shape ?? 1.0}
                  minValue={0.1}
                  maxValue={3}
                  step={0.05}
                  onChange={(v) => setPf((s) => ({ ...s, drop_shape: v }))}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Dept weight">
                <NumberInput
                  value={pf.dept_weight ?? 0.4}
                  minValue={0}
                  maxValue={1}
                  step={0.05}
                  onChange={(v) => setPf((s) => ({ ...s, dept_weight: v }))}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Force pick allowed">
                <Button.Checkbox
                  checked={!!pf.allow_force_pick}
                  onClick={() =>
                    setPf((s) => ({
                      ...s,
                      allow_force_pick: !s.allow_force_pick,
                    }))
                  }
                >
                  Force pick
                </Button.Checkbox>
              </LabeledList.Item>
              <LabeledList.Item label="Assist window">
                <NumberInput
                  value={pf.assist_window ?? 0}
                  minValue={0}
                  maxValue={50}
                  step={1}
                  onChange={(v) => setPf((s) => ({ ...s, assist_window: v }))}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Assist prob (%)">
                <NumberInput
                  value={pf.assist_prob ?? 0}
                  minValue={0}
                  maxValue={100}
                  step={5}
                  onChange={(v) => setPf((s) => ({ ...s, assist_prob: v }))}
                />
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>
        </Stack>

        <Box mt={1}>
          <Button
            icon="save"
            onClick={() => act('update_profile', { changes: pf })}
          >
            Save profile
          </Button>
        </Box>
      </Section>

      {/* Глобальные параметры */}
      <Section title="Storyteller globals">
        <Stack>
          <Stack.Item grow>
            <LabeledList>
              <LabeledList.Item label="Smooth window (sec)">
                <NumberInput
                  value={gl.smooth_window_sec ?? 120}
                  minValue={10}
                  maxValue={1800}
                  step={10}
                  onChange={(v) =>
                    setGl((s) => ({ ...s, smooth_window_sec: v }))
                  }
                />
              </LabeledList.Item>
              <LabeledList.Item label="Default cooldown (sec)">
                <NumberInput
                  value={gl.cooldown_default_sec ?? 300}
                  minValue={0}
                  maxValue={7200}
                  step={10}
                  onChange={(v) =>
                    setGl((s) => ({ ...s, cooldown_default_sec: v }))
                  }
                />
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>
        </Stack>

        <Box mt={1}>
          <Button
            icon="save"
            onClick={() => act('update_globals', { changes: gl })}
          >
            Save globals
          </Button>
        </Box>
      </Section>

      {/* Редактор фаз */}
      <PhasePlanEditor
        plan={Array.isArray(data.phase_plan) ? (data.phase_plan as any[]) : []}
        act={act}
        // catalog={data.catalog} // если позже начнёшь отдавать каталог с бэка
      />
    </>
  );
};

const DebugTab: React.FC<{ data: Data }> = ({ data }) => {
  const phase = data.phase || {};
  const phaseTotal = Number(data.phase_total || 0);
  const hasPhase = (phase.index ?? -1) >= 0;

  return (
    <>
      <Section title="Phase">
        {hasPhase ? (
          <LabeledList>
            <LabeledList.Item label="Now">
              {`Phase ${Number(phase.index)}${phaseTotal ? ` / ${phaseTotal}` : ''}`}
            </LabeledList.Item>
            <LabeledList.Item label="Title">
              {phase.title || '—'}
            </LabeledList.Item>
            <LabeledList.Item label="Duration">
              {(phase.duration_min ?? 0) || 0} min
            </LabeledList.Item>
            <LabeledList.Item label="Pool size">
              {(phase.pool_count ?? 0) || 0}
            </LabeledList.Item>
            {phase.description ? (
              <LabeledList.Item label="Description">
                <Box color="label">{phase.description}</Box>
              </LabeledList.Item>
            ) : null}
          </LabeledList>
        ) : (
          <Box color="label">No active phase</Box>
        )}
      </Section>

      <Section title="Raw payload">
        <FixedScroll h="24rem">
          <Box as="pre" style={{ whiteSpace: 'pre-wrap' }}>
            {JSON.stringify(
              {
                profile: data.profile,
                target: data.target,
                chaos: data.chaos,
                chaos_breakdown: data.chaos_breakdown,
                departments: data.departments,
                scored: data.scored,
                history: data.history,
                raw_state: data.raw_state,
                cached_state: data.cached_state,
                globals: data.globals,
              },
              null,
              2,
            )}
          </Box>
        </FixedScroll>
      </Section>
    </>
  );
};

/* ============================
 * Root component
 * ============================ */

export const Storyteller: React.FC = () => {
  const { data, act } = useBackend<Data>();
  const [tab, setTab] = useState<'metrics' | 'settings' | 'debug'>('metrics');

  if (data.inactive) {
    return (
      <Window width={1100} height={760}>
        <Window.Content scrollable>
          <NoticeBox danger>Storyteller не активен.</NoticeBox>
        </Window.Content>
      </Window>
    );
  }

  const title = `Storyteller — ${data.profile?.name || 'Unknown'}`;

  return (
    <Window width={1100} height={760}>
      <Window.Content scrollable>
        <Stack vertical fill>
          <TopBar title={title} tab={tab} setTab={setTab} act={act} />
          {tab === 'metrics' && <MetricsTab data={data} act={act} />}
          {tab === 'settings' && <SettingsTab data={data} act={act} />}
          {tab === 'debug' && <DebugTab data={data} />}
        </Stack>
      </Window.Content>
    </Window>
  );
};
