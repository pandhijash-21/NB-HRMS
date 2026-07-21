import { Router } from 'express';
import { employeeRouter } from './employee.routes';
import { generalRouter } from './general.routes';
import { personalRouter } from './personal.routes';
import { addressRouter } from './address.routes';
import { otherRouter } from './other.routes';
import { bankRouter } from './bank.routes';
import { familyRouter } from './family.routes';
import { academicRouter } from './academic.routes';
import { uploadRouter } from './upload.routes';
import { auditRouter } from './audit.routes';
import { experienceRouter } from './experience.routes';

export const personalEducationRouter = Router();
personalEducationRouter.use('/employees', employeeRouter);
personalEducationRouter.use('/employees', generalRouter);
personalEducationRouter.use('/employees', personalRouter);
personalEducationRouter.use('/employees', addressRouter);
personalEducationRouter.use('/employees', otherRouter);
personalEducationRouter.use('/employees', bankRouter);
personalEducationRouter.use('/employees', familyRouter);
personalEducationRouter.use('/employees', academicRouter);
personalEducationRouter.use('/employees', experienceRouter);
personalEducationRouter.use('/upload', uploadRouter);
personalEducationRouter.use('/employees', auditRouter);

