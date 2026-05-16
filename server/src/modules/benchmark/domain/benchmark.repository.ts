import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { CohortAggregate } from './entities/benchmark.entity';

const COHORT_AGGREGATES_COLLECTION = 'cohort_aggregates';
const MAX_SIZE = 1000;

export class BenchmarkRepository {
  async findAggregate(level: string, runType: string, distance: string): Promise<CohortAggregate | null> {
    const db = getFirestore();
    const docRef = db.collection(COHORT_AGGREGATES_COLLECTION).doc(`${level}_${runType}_${distance}`);
    const doc = await docRef.get();

    if (!doc.exists) {
      return null;
    }

    const data = doc.data();
    if (!data) {
      return null;
    }

    return {
      id: doc.id,
      level: data.level || level,
      runType: data.runType || runType,
      distance: data.distance || distance,
      cohortSize: data.cohortSize || 0,
      paceAvgs: Array.isArray(data.paceAvgs) ? data.paceAvgs : [],
      bpmAvgs: Array.isArray(data.bpmAvgs) ? data.bpmAvgs : [],
      distAvgs: Array.isArray(data.distAvgs) ? data.distAvgs : [],
      consistencyAvgs: Array.isArray(data.consistencyAvgs) ? data.consistencyAvgs : [],
      updatedAt: data.updatedAt || new Date().toISOString(),
    };
  }

  async createOrIncrementAggregate(
    level: string,
    runType: string,
    distance: string,
  ): Promise<void> {
    const db = getFirestore();
    const docRef = db.collection(COHORT_AGGREGATES_COLLECTION).doc(`${level}_${runType}_${distance}`);

    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);

      if (!doc.exists) {
        transaction.set(docRef, {
          level,
          runType,
          distance,
          cohortSize: 1,
          paceAvgs: [],
          bpmAvgs: [],
          distAvgs: [],
          consistencyAvgs: [],
          updatedAt: new Date().toISOString(),
        });
      } else {
        transaction.update(docRef, {
          cohortSize: (doc.data()?.cohortSize || 0) + 1,
          updatedAt: new Date().toISOString(),
        });
      }
    });
  }

  async addMetricToAggregate(
    level: string,
    runType: string,
    distance: string,
    metric: 'paceAvgs' | 'bpmAvgs' | 'distAvgs' | 'consistencyAvgs',
    value: number,
  ): Promise<void> {
    const db = getFirestore();
    const docRef = db.collection(COHORT_AGGREGATES_COLLECTION).doc(`${level}_${runType}_${distance}`);

    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);

      if (!doc.exists) {
        throw new Error(`Aggregate not found: ${level}_${runType}_${distance}`);
      }

      const current = doc.data();
      if (!current) {
        throw new Error(`Aggregate data not found: ${level}_${runType}_${distance}`);
      }

      const currentArray = Array.isArray(current[metric]) ? current[metric] : [];
      const newArray = [...currentArray, value];

      if (newArray.length > MAX_SIZE) {
        newArray.shift();
      }

      transaction.update(docRef, {
        [metric]: newArray,
        updatedAt: new Date().toISOString(),
      });
    });
  }
}
