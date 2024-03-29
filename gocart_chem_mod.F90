module gocart_chem_mod

  use gsd_chem_constants ,        only : kind_chem

  use gsd_chem_config, only : airmw, smw,                      &
                              p_o3,p_qi,p_qc,p_qv,p_dms,p_so2, &
                              p_sulf,p_msa,p_ho,p_h2o2,p_no3,  &
                              ndms, nso2, nso4, nmsa

  implicit none

  public

contains

  subroutine gocart_chem_driver(ktau,dtlt,dt,gmt,julday,xcosz,t_phy,moist,  &
         chem,rho_phy,dz8w,p8w,backg_oh,oh_t,backg_h2o2,h2o2_t,backg_no3,no3_t, &
         area,g,xlat,xlong,ttday,tcosz, &
         chem_opt,num_chem,num_moist,                                      &
         ids,ide, jds,jde, kds,kde,                                        &
         ims,ime, jms,jme, kms,kme,                                        &
         its,ite, jts,jte, kts,kte                                         )
  IMPLICIT NONE

   INTEGER,      INTENT(IN   ) :: julday, ktau,                     &
                                  chem_opt,num_chem,num_moist,      &
                                  ids,ide, jds,jde, kds,kde,        &
                                  ims,ime, jms,jme, kms,kme,        &
                                  its,ite, jts,jte, kts,kte
   REAL(kind_chem), DIMENSION( ims:ime, kms:kme, jms:jme, num_moist ),                &
         INTENT(IN ) ::                                   moist
   REAL(kind_chem), DIMENSION( ims:ime, kms:kme, jms:jme, num_chem ),                 &
         INTENT(INOUT ) ::                                      chem
   REAL(kind_chem),  DIMENSION( ims:ime , jms:jme ),                        &
          INTENT(IN   ) ::                                                 &
              area,xlat,xlong,ttday,tcosz,xcosz
   REAL(kind_chem),  DIMENSION( ims:ime , kms:kme , jms:jme ),                        &
          INTENT(IN   ) ::                     t_phy,               &
                              backg_oh,backg_h2o2,backg_no3,dz8w,p8w,      &
                                              rho_phy
   REAL(kind_chem),  DIMENSION( ims:ime , kms:kme , jms:jme ),                        &
          INTENT(OUT   ) ::                     oh_t,h2o2_t,no3_t

  REAL(kind_chem), INTENT(IN   ) :: dt,g,gmt,dtlt
  integer :: nmx,i,j,k,imx,jmx,lmx
  real(kind_chem), DIMENSION (1,1,1) :: tmp,airden,airmas,oh,xno3,h2o2,chldms_oh,    &
                               chldms_no3,chldms_x,chpso2,chpmsa,chpso4,    &
                               chlso2_oh,chlso2_aq,cldf
  real(kind_chem), DIMENSION (1,1,4) :: tdry
  real(kind_chem), DIMENSION (1,1) :: cossza
  real(kind_chem), DIMENSION (1,1) :: sza,cosszax
  real(kind_chem), DIMENSION (1,1,1,4) :: tc,bems
  real(kind_chem), dimension (1) :: dxy
  real(kind_chem):: rlat,xlonn
  real(kind_chem):: xtime,zenith,zenita,azimuth,xhour,xmin,xtimin,gmtp
      INTEGER :: ixhour
       imx=1
       jmx=1
       lmx=1
       nmx=4
       tdry=0.d0
      xtime=ktau*dtlt/60.
      ixhour=int(gmt+.01)+int(xtime/60.)
      xhour=float(ixhour)
      xmin=60.*gmt+(xtime-xhour*60.)
      gmtp=mod(xhour,24.)
      gmtp=gmtp+xmin/60.
     
      oh_t(:,:,:)=0.0 
      h2o2_t(:,:,:)=0.0 
      no3_t(:,:,:)=0.0 
!
! following arrays for busget stuff only
!
!
!
!      chem_select: SELECT CASE(config_flags%chem_opt)
!         CASE (GOCART_SIMPLE)
!          CALL wrf_debug(15,'calling gocart chemistry ')
       if(chem_opt == 300 .or. chem_opt==316  .or. chem_opt==317)then
!TBH       write(6,*)'in gocart_chem, julday = ',julday
       do j=jts,jte
       do i=its,ite
        dxy(1)=area(i,j)
        zenith=0.
        zenita=0.
        azimuth=0.
        rlat=xlat(i,j)*3.1415926535590/180.
        xlonn=xlong(i,j)
        CALL szangle(1, 1, julday, gmtp, sza, cosszax,xlonn,rlat)
        cossza(1,1)=cosszax(1,1)
        !--use physics inst cosine zenith --hli 03/06/2020
!        cossza(1,1)=xcosz(i,j)
!
       do k=kts,kte 
       chldms_oh=0.
       chldms_no3=0.
       chldms_x=0.
       chpso2=0.
       chpmsa=0.
       chpso4=0.
       chlso2_oh=0.
       chlso2_aq=0.
          cldf(1,1,1)=0. ! wet removal not be done here for SO2 and sulfate
          !if(p_qc.gt.1)then
          !   if(moist(i,k,j,p_qc).gt.0.)cldf(1,1,1)=1.
          !endif
          !if(p_qi.gt.1)then
          !   if(moist(i,k,j,p_qi).gt.0.)cldf(1,1,1)=1.
          !endif
          tc(1,1,1,1)=chem(i,k,j,p_dms)*1.d-6
          tc(1,1,1,2)=chem(i,k,j,p_so2)*1.d-6
          tc(1,1,1,3)=chem(i,k,j,p_sulf)*1.d-6
          tc(1,1,1,4)=chem(i,k,j,p_msa)*1.d-6
          airmas(1,1,1)=-(p8w(i,k+1,j)-p8w(i,k,j))*area(i,j)/g
          airden(1,1,1)=rho_phy(i,k,j)
          tmp(1,1,1)=t_phy(i,k,j)
if (tcosz(i,j)/=0.0) then
          oh(1,1,1)=86400./dtlt*cossza(1,1)*backg_oh(i,k,j)/tcosz(i,j)
else
          oh(1,1,1)=1.0E-20
endif

          oh_t(i,k,j)=oh(1,1,1)*1.e6
! TBH:  END HACK
          h2o2(1,1,1)=backg_h2o2(i,k,j)
           IF (COSSZA(1,1) > 0.0) THEN
              XNO3(1,1,1) = 0.0
           ELSE
              ! -- Fraction of night
              ! fnight       = 1.0 - TTDAY(i,j)/86400.0
              ! The original xno3 values have been averaged over daytime
              ! as well => divide by fnight to get the appropriate night-time
              ! fraction from the monthly average
              ! fnight/=0.0 (for fnight=0: all cosszax (including current
              ! cossza) > 0.0)
              xno3(1,1,1) = backg_no3(i,k,j) / (1.0 - TTDAY(i,j)/86400.)
           END IF

          call chmdrv_su( imx,jmx,lmx,&
               nmx, dt, tmp, airden, airmas, &
               oh, xno3, h2o2, cldf, tc, tdry,cossza,  &
               chldms_oh, chldms_no3, chldms_x, chpso2, chpmsa, chpso4, &
               chlso2_oh, chlso2_aq)
          chem(i,k,j,p_dms)=tc(1,1,1,1)*1.e6
          chem(i,k,j,p_so2)=tc(1,1,1,2)*1.e6
          chem(i,k,j,p_sulf)=tc(1,1,1,3)*1.e6
          chem(i,k,j,p_msa)=tc(1,1,1,4)*1.e6
          h2o2_t(i,k,j)=h2o2(1,1,1)*1.e6
          no3_t(i,k,j)=xno3(1,1,1)*1.e6
       enddo
       enddo
       enddo
     else if(chem_opt.eq.301)then
!TBH       write(0,*)'calling gocart chemistry in addition to racm_kpp'
       do j=jts,jte
       do i=its,ite
        zenith=0.
        zenita=0.
        azimuth=0.
        rlat=xlat(i,j)*3.1415926535590/180.
        xlonn=xlong(i,j)
        CALL szangle(1, 1, julday, gmtp, sza, cosszax,xlonn,rlat)
        cossza(1,1)=cosszax(1,1)
       do k=kts,kte 
       chldms_oh=0.
       chldms_no3=0.
       chldms_x=0.
       chpso2=0.
       chpmsa=0.
       chpso4=0.
       chlso2_oh=0.
       chlso2_aq=0.
          cldf(1,1,1)=0. ! wet removal not be done here for SO2 and sulfate

          tc(1,1,1,1)=chem(i,k,j,p_dms)*1.d-6
          tc(1,1,1,2)=chem(i,k,j,p_so2)*1.d-6
          tc(1,1,1,3)=chem(i,k,j,p_sulf)*1.d-6
          tc(1,1,1,4)=chem(i,k,j,p_msa)*1.d-6
          airmas(1,1,1)=-(p8w(i,k+1,j)-p8w(i,k,j))*area(i,j)/g
          airden(1,1,1)=rho_phy(i,k,j)
          tmp(1,1,1)=t_phy(i,k,j)
          oh(1,1,1)=chem(i,k,j,p_ho)*1.d-6
          h2o2(1,1,1)=chem(i,k,j,p_h2o2)*1.d-6
          xno3(1,1,1) = chem(i,k,j,p_no3)*1.d-6
          IF (COSSZA(1,1) > 0.0)xno3(1,1,1) = 0. 
!         if(i.eq.19.and.j.eq.19.and.k.eq.kts)then
!          write(0,*)backg_oh(i,k,j),backg_no3(i,k,j),ttday(i,j),tcosz(i,j)
!         endif

          call chmdrv_su( imx,jmx,lmx,&
               nmx, dt, tmp, airden, airmas, &
               oh, xno3, h2o2, cldf, tc, tdry,cossza,  &
               chldms_oh, chldms_no3, chldms_x, chpso2, chpmsa, chpso4, &
               chlso2_oh, chlso2_aq)
          chem(i,k,j,p_dms)=tc(1,1,1,1)*1.e6
          chem(i,k,j,p_so2)=tc(1,1,1,2)*1.e6
          chem(i,k,j,p_sulf)=tc(1,1,1,3)*1.e6
          chem(i,k,j,p_msa)=tc(1,1,1,4)*1.e6
       enddo
       enddo
       enddo
   endif
!  END SELECT chem_select
end subroutine gocart_chem_driver

!SUBROUTINE chmdrv_su( &
!     imx, jmx, lmx, nmx, ndt1, tmp, drydf, airden, airmas, &
!     oh, xno3, h2o2, cldf, tc, tdry, depso2, depso4, depmsa, &
!     chldms_oh, chldms_no3, chldms_x, chpso2, chpmsa, chpso4, &
!     chlso2_oh, chlso2_aq)

!We don't apply losses due to dry deposition here, this is done in vertical mixing
SUBROUTINE chmdrv_su( imx,jmx,lmx,&
     nmx, dt1, tmp, airden, airmas, &
     oh, xno3, h2o2, cldf, tc, tdry,cossza,  &
     chldms_oh, chldms_no3, chldms_x, chpso2, chpmsa, chpso4, &
     chlso2_oh, chlso2_aq)

! ****************************************************************************
! **                                                                        **
! **  Chemistry subroutine.  For tracers with dry deposition, the loss      **
! **  rate of dry dep is combined in chem loss term.                        **
! **                                                                        **
! ****************************************************************************

! USE module_data_gocart
  
  IMPLICIT NONE

  INTEGER, INTENT(IN) :: nmx,imx,jmx,lmx
  integer :: ndt1
  real(kind_chem), intent(in) :: dt1
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(IN) :: tmp, airden, airmas
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(IN) :: oh, xno3, cldf
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(INOUT) :: h2o2
!  REAL(kind_chem), INTENT(IN)    :: drydf(imx,jmx,nmx)
  REAL(kind_chem), INTENT(INOUT) :: tc(imx,jmx,lmx,nmx)
  REAL(kind_chem), INTENT(INOUT) :: tdry(imx,jmx,nmx)
  real(kind_chem), DIMENSION (imx,jmx),INTENT(IN) :: cossza
!  REAL(kind_chem), DIMENSION(imx,jmx),     INTENT(INOUT) :: depso2, depso4, depmsa
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(INOUT) :: chldms_oh, chldms_no3
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(INOUT) :: chldms_x, chpso2, chpmsa
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(INOUT) :: chpso4, chlso2_oh, chlso2_aq

  REAL(kind_chem), DIMENSION(imx,jmx,lmx) :: pso2_dms, pmsa_dms, pso4_so2

  ! executable statements
  ndt1=int(dt1)
  if(ndt1.le.0)stop

     CALL chem_dms(imx,jmx,lmx,nmx, ndt1, tmp, airden, airmas, oh, xno3, &
          tc, chldms_oh, chldms_no3, chldms_x, chpso2, chpmsa,cossza, &
          pso2_dms, pmsa_dms)
     CALL chem_so2(imx,jmx,lmx,nmx, ndt1, tmp, airden, airmas, &
          cldf, oh, h2o2, tc, tdry, cossza,&
          chpso4, chlso2_oh, chlso2_aq, pso2_dms, pso4_so2)
!          depso2, chpso4, chlso2_oh, chlso2_aq, pso2_dms, pso4_so2)
     CALL chem_so4(imx,jmx,lmx,nmx, ndt1, airmas, tc, tdry,cossza, &
          pso4_so2)
!          depso4, pso4_so2)
     CALL chem_msa(imx,jmx,lmx,nmx, ndt1, airmas, tc, tdry, cossza,&
          pmsa_dms)
!          depmsa, pmsa_dms)
  
END SUBROUTINE chmdrv_su

!=============================================================================
SUBROUTINE chem_dms( imx,jmx,lmx,&
     nmx, ndt1, tmp, airden, airmas, oh, xno3, &
     tc, chldms_oh, chldms_no3, chldms_x, chpso2, chpmsa,cossza, &
     pso2_dms, pmsa_dms)

! ****************************************************************************
! *                                                                          *
! *  This is DMS chemistry subroutine.                                       *
! *                                                                          *
! *  R1:    DMS + OH  -> a*SO2 + b*MSA                OH addition channel    *
! *         k1 = { 1.7e-42*exp(7810/T)*[O2] / (1+5.5e-31*exp(7460/T)*[O2] }  *
! *         a = 0.75, b = 0.25                                               *
! *                                                                          *
! *  R2:    DMS + OH  ->   SO2 + ...                  OH abstraction channel *
! *         k2 = 1.2e-11*exp(-260/T)                                         *
! *                                                                          *
! *     DMS_OH = DMS0 * exp(-(r1+r2)*NDT1)                                   *
! *         where DMS0 is the DMS concentration at the beginning,            *
! *         r1 = k1*[OH], r2 = k2*[OH].                                      *
! *                                                                          *
! *  R3:    DMS + NO3 ->   SO2 + ...                                         *
! *         k3 = 1.9e-13*exp(500/T)                                          *
! *                                                                          *
! *     DMS = DMS_OH * exp(-r3*NDT1)                                         *
! *         where r3 = k3*[NO3].                                             *
! *                                                                          *
! *  R4:    DMS + X   ->   SO2 + ...                                         *
! *         assume to be at the rate of DMS+OH and DMS+NO3 combined.         *
! *                                                                          *
! *  The production of SO2 and MSA here, PSO2_DMS and PMSA_DMS, are saved    *
! *  for use in CHEM_SO2 and CHEM_MSA subroutines as a source term.  They    *
! *  are in unit of MixingRatio/timestep.                                    *
! *                                                                          *
! **************************************************************************** 

! USE module_data_gocart_chem

  IMPLICIT NONE

  INTEGER, INTENT(IN) :: nmx, ndt1,imx,jmx,lmx
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(IN) :: tmp, airden, airmas
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(IN) :: oh, xno3
  REAL(kind_chem), INTENT(INOUT) :: tc(imx,jmx,lmx,nmx)
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(INOUT) :: chldms_oh, chldms_no3
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(INOUT) :: chldms_x, chpso2, chpmsa
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(OUT)   :: pso2_dms, pmsa_dms
  real(kind_chem), DIMENSION (imx,jmx),INTENT(IN) :: cossza

  REAL(kind_chem), PARAMETER :: fx = 1.0 
  REAL(kind_chem), PARAMETER :: a = 0.75
  REAL(kind_chem), PARAMETER :: b = 0.25
  
  ! From D4: only 0.8 efficiency, also some goes to DMSO and lost. 
  ! So we assume 0.75 efficiency for DMS addtion channel to form    
  ! products.                                                       
  
  REAL(kind_chem), PARAMETER :: eff = 1.0
  ! -- Factor to convert AIRDEN from kgair/m3 to molecules/cm3: 
  REAL(kind_chem), PARAMETER :: f = 1000.0 / airmw * 6.022D23 * 1.0D-6
  INTEGER :: i, j, l
  REAL(kind_chem) :: tk, o2, dms0, rk1, rk2, rk3, dms_oh, dms, xoh, xn3, xx
  
  ! executable statements
  
  DO l = 1,lmx
!CMIC$ doall autoscope
     DO j = 1,jmx
        DO i = 1,imx
           
           tk = tmp(i,j,l)
           o2 = airden(i,j,l) * f * 0.21
           dms0 = tc(i,j,l,NDMS)
           
! ****************************************************************************
! *  (1) DMS + OH:  RK1 - addition channel;  RK2 - abstraction channel.      *
! ****************************************************************************

           rk1 = 0.0d0
           rk2 = 0.0d0
           rk3 = 0.0d0
           
           IF (oh(i,j,l) > 0.0) THEN
!             IF (TRIM(oh_units) == 'mol/mol') THEN
                 ! mozech: oh is in mol/mol
                 ! convert to molecules/cm3
                 rk1 = (1.7D-42 * EXP(7810.0/tk) * o2) / &
                      (1.0 + 5.5D-31 * EXP(7460.0/tk) * o2 ) * oh(i,j,l) * &
                      airden(i,j,l)*f
                 rk2 = 1.2D-11*EXP(-260.0/tk) * oh(i,j,l)*airden(i,j,l)*f
!             ELSE
!                rk1 = (1.7D-42 * EXP(7810.0/tk) * o2) / &
!                     (1.0 + 5.5D-31 * EXP(7460.0/tk) * o2 ) * oh(i,j,l)
!                rk2 = 1.2D-11*EXP(-260.0/tk) * oh(i,j,l) 
!             END IF
           END IF
           
! ****************************************************************************
! *  (2) DMS + NO3 (only happens at night):                                  *
! ****************************************************************************

           IF (cossza(i,j) <= 0.0) THEN

!             IF (TRIM(no3_units) == 'cm-3') THEN
!                ! IMAGES: XNO3 is in molecules/cm3.     
!                rk3 = 1.9D-13 * EXP(500.0/tk) * xno3(i,j,l)

!             ELSE
                 ! GEOSCHEM (mergechem) and mozech: XNO3 is in mol/mol (v/v)
                 ! convert xno3 from volume mixing ratio to molecules/cm3 
                 rk3 = 1.9D-13 * EXP(500.0/tk) * xno3(i,j,l) * &
                      airden(i,j,l) * f
!             END IF
              
           END IF

! ****************************************************************************
! *  Update DMS concentrations after reaction with OH and NO3, and also      *
! *  account for DMS + X assuming at a rate as (DMS+OH)*Fx in the day and    *
! *  (DMS+NO3)*Fx at night:                                                  *
! *       DMS_OH       :  DMS concentration after reaction with OH           *
! *       DMS          :  DMS concentration after reaction with NO3          *
! *                           (min(DMS) = 1.0E-32)                           *
! ****************************************************************************

           dms_oh = dms0   * EXP( -(rk1 + rk2) * fx * REAL(ndt1) )
           dms    = dms_oh * EXP( -(rk3) * fx * REAL(ndt1) )
           dms    = MAX(dms, 1.0D-16)
           
           tc(i,j,l,NDMS) = dms
           
! ****************************************************************************
! *  Save SO2 and MSA production from DMS oxidation                          * 
! *  (in MixingRatio/timestep):                                              *
! *                                                                          *
! *  SO2 is formed in DMS + OH addition (0.85) and abstraction (1.0)         *
! *      channels as well as DMS + NO3 reaction.  We also assume that        *
! *      SO2 yield from DMS + X is 1.0.                                      *
! *  MSA is formed in DMS + OH addition (0.15) channel.                      *
! ****************************************************************************
       
           IF ((rk1 + rk2) == 0.0) THEN
              pmsa_dms(i,j,l) = 0.0
           ELSE
!       pmsa_dms(i,j,l) = (dms0 - dms_oh) * b*rk1/((rk1+rk2)*fx)
              pmsa_dms(i,j,l) = (dms0 - dms_oh) * b*rk1/((rk1+rk2) * fx) * eff
           END IF
           pso2_dms(i,j,l) =  dms0 - dms - pmsa_dms(i,j,l)
!      pso2_dms(i,j,l) =  (dms0 - dms - pmsa_dms(i,j,l)/eff) * eff

           !    ------------------------------------------------------------
           !    DIAGNOSTICS:      DMS loss       (kgS/timstep)          
           !                      SO2 production (kgS/timestep)         
           !                      MSA production (kgS/timestep)         
           !    ------------------------------------------------------------
           xoh  = (dms0   - dms_oh) / fx  * airmas(i,j,l)/airmw*smw
           xn3  = (dms_oh - dms)    / fx  * airmas(i,j,l)/airmw*smw
           xx   = (dms0 - dms) * airmas(i,j,l)/airmw*smw - xoh - xn3

           chldms_oh (i,j,l) = chldms_oh (i,j,l) + xoh
           chldms_no3(i,j,l) = chldms_no3(i,j,l) + xn3
           chldms_x  (i,j,l) = chldms_x  (i,j,l) + xx
           
           chpso2(i,j,l) = chpso2(i,j,l) + pso2_dms(i,j,l) &
                * airmas(i,j,l) / airmw * smw
           chpmsa(i,j,l) = chpmsa(i,j,l) + pmsa_dms(i,j,l) &
                * airmas(i,j,l) / airmw * smw
           
        END DO
     END DO
  END DO
  
END SUBROUTINE chem_dms
      
!=============================================================================

SUBROUTINE chem_so2( imx,jmx,lmx,&
     nmx, ndt1, tmp, airden, airmas, &
     cldf, oh, h2o2, tc, tdry, cossza,&
     chpso4, chlso2_oh, chlso2_aq, pso2_dms, pso4_so2)
!     depso2, chpso4, chlso2_oh, chlso2_aq, pso2_dms, pso4_so2)

! ****************************************************************************
! *                                                                          *
! *  This is SO2 chemistry subroutine.                                       *
! *                                                                          *
! *  SO2 production:                                                         *
! *    DMS + OH, DMS + NO3 (saved in CHEM_DMS)                               * 
! *                                                                          *
! *  SO2 loss:                                                               * 
! *    SO2 + OH  -> SO4                                                      *
! *    SO2       -> drydep (NOT USED IN WRF/CHEM                             *
! *    SO2 + H2O2 or O3 (aq) -> SO4                                          *
! *                                                                          *
! *  SO2 = SO2_0 * exp(-bt)                                                  *
! *      + PSO2_DMS/bt * [1-exp(-bt)]                                        *
! *    where b is the sum of the reaction rate of SO2 + OH and the dry       *
! *    deposition rate of SO2, PSO2_DMS is SO2 production from DMS in        *
! *    MixingRatio/timestep.                                                 *
! *                                                                          *
! *  If there is cloud in the gridbox (fraction = fc), then the aqueous      *
! *  phase chemistry also takes place in cloud. The amount of SO2 oxidized   *
! *  by H2O2 in cloud is limited by the available H2O2; the rest may be      *
! *  oxidized due to additional chemistry, e.g, reaction with O3 or O2       *
! *  (catalyzed by trace metal).                                             *
! *                                                                          *
! ****************************************************************************
! USE module_data_gocart_chem

  IMPLICIT NONE

  INTEGER, INTENT(IN) ::  nmx, ndt1,imx,jmx,lmx
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(IN) :: tmp, airden, airmas
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(IN) :: cldf, oh
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(INOUT) :: h2o2
  real(kind_chem), DIMENSION (imx,jmx),INTENT(IN) :: cossza
!  REAL(kind_chem), INTENT(IN)    :: drydf(imx,jmx,nmx)
  REAL(kind_chem), INTENT(INOUT) :: tc(imx,jmx,lmx,nmx)
  REAL(kind_chem), INTENT(INOUT) :: tdry(imx,jmx,nmx)

!  REAL(kind_chem), DIMENSION(imx,jmx),     INTENT(INOUT) :: depso2
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(INOUT) :: chpso4, chlso2_oh, chlso2_aq
  REAL(kind_chem), INTENT(IN)  :: pso2_dms(imx,jmx,lmx)
  REAL(kind_chem), INTENT(OUT) :: pso4_so2(imx,jmx,lmx)

  REAL(kind_chem) ::  k0, kk, m, l1, l2, ld
  ! Factor to convert AIRDEN from kgair/m3 to molecules/cm3: 
  REAL(kind_chem), PARAMETER :: f  = 1000. / airmw * 6.022D23 * 1.0D-6
  REAL(kind_chem), PARAMETER :: ki = 1.5D-12
  INTEGER :: i, j, l
  REAL(kind_chem) :: so20, tk, f1, rk1, rk2, rk, rkt, so2_cd, fc, so2

  ! executable statements

  DO l = 1,lmx
     DO j = 1,jmx
        DO i = 1,imx
           
           so20 = tc(i,j,l,NSO2)

           ! RK1: SO2 + OH(g), in s-1 
           tk = tmp(i,j,l)
           k0 = 3.0D-31 * (300.0/tk)**3.3
           m  = airden(i,j,l) * f
           kk = k0 * m / ki
           f1 = ( 1.0+ ( LOG10(kk) )**2 )**(-1)
!          IF (TRIM(oh_units) == 'mol/mol') THEN 
              ! mozech: oh is in mol/mol
              ! convert to molecules/cm3
              rk1 = ( k0 * m / (1.0 + kk) ) * 0.6**f1 * &
                   oh(i,j,l)*airden(i,j,l)*f
!          ELSE
!             rk1 = ( k0 * m / (1.0 + kk) ) * 0.6**f1 * oh(i,j,l)
!          END IF
      
           ! RK2: SO2 drydep frequency, s-1 
!           IF (l == 1) THEN ! at the surface
!              rk2 = drydf(i,j,NSO2)
!           ELSE
              rk2 = 0.0
!           END IF
           
           rk  = (rk1 + rk2)
           rkt =  rk * REAL(ndt1)

! ****************************************************************************
! *  Update SO2 concentration after gas phase chemistry and deposition.      *
! ****************************************************************************

           IF (rk > 0.0) THEN
              so2_cd = so20 * EXP(-rkt) &
                   + pso2_dms(i,j,l) * (1.0 - EXP(-rkt)) / rkt
              l1     = (so20 - so2_cd + pso2_dms(i,j,l)) * rk1/rk
              IF (l == 1) THEN
                 ld    = (so20 - so2_cd + pso2_dms(i,j,l)) * rk2/rk
              ELSE
                 ld    = 0.0
              END IF
           ELSE
              so2_cd = so20
              l1 = 0.0
           END IF

! ****************************************************************************
! *  Update SO2 concentration after cloud chemistry.                         *
! *  SO2 chemical loss rate  = SO4 production rate (MixingRatio/timestep).   *
! ****************************************************************************

           ! Cloud chemistry (above 258K): 
           fc = cldf(i,j,l)
           IF (fc > 0.0 .AND. so2_cd > 0.0 .AND. tk > 258.0) THEN

              IF (so2_cd > h2o2(i,j,l)) THEN
                 fc = fc * (h2o2(i,j,l)/so2_cd)
                 h2o2(i,j,l) = h2o2(i,j,l) * (1.0 - cldf(i,j,l))
              ELSE
                 h2o2(i,j,l) = h2o2(i,j,l) * &
                      (1.0 - cldf(i,j,l)*so2_cd/h2o2(i,j,l))
              END IF
              so2 = so2_cd * (1.0 - fc)
              ! Aqueous phase SO2 loss rate (MixingRatio/timestep): 
              l2  = so2_cd * fc 
           ELSE
              so2 = so2_cd
              l2 = 0.0
           END IF

           so2    = MAX(so2, 1.0D-16)
           tc(i,j,l,NSO2) = so2

! ****************************************************************************
! *  SO2 chemical loss rate  = SO4 production rate (MixingRatio/timestep).   *
! ****************************************************************************

           pso4_so2(i,j,l) = l1 + l2

           !    ---------------------------------------------------------------
           !    DIAGNOSTICS:      SO2 gas-phase loss       (kgS/timestep)  
           !                      SO2 aqueous-phase loss   (kgS/timestep) 
           !                      SO2 dry deposition loss  (kgS/timestep) 
           !                      SO4 production           (kgS/timestep) 
           !    ---------------------------------------------------------------
           chlso2_oh(i,j,l) = chlso2_oh(i,j,l) &
                + l1 * airmas(i,j,l) / airmw * smw
           chlso2_aq(i,j,l) = chlso2_aq(i,j,l) &
                + l2 * airmas(i,j,l) / airmw * smw
           IF (l == 1) &
!                depso2(i,j) = depso2(i,j) + ld * airmas(i,j,l) / airmw * smw

           chpso4(i,j,l) = chpso4(i,j,l) + pso4_so2(i,j,l) &
                * airmas(i,j,l) / airmw * smw
           
        END DO
     END DO
  END DO

!  tdry(:,:,NSO2) = depso2(:,:)*tcmw(NSO2)/smw ! kg of SO2

END SUBROUTINE chem_so2

!=============================================================================

SUBROUTINE chem_so4( imx,jmx,lmx,&
     nmx, ndt1, airmas, tc, tdry, cossza,&
     pso4_so2)
!     depso4, pso4_so2)

! ****************************************************************************
! *                                                                          *
! *  This is SO4 chemistry subroutine.                                       *
! *                                                                          *
! *  The Only production is from SO2 oxidation (save in CHEM_SO2), and the   *
! *  only loss is dry depsition here.  Wet deposition will be treated in     *
! *  WETDEP subroutine.                                                      *
! *                                                                          *
! *  SO4 = SO4_0 * exp(-kt) + PSO4_SO2/kt * (1.-exp(-kt))                    *
! *    where k = dry deposition.                                             *
! *                                                                          *
! ****************************************************************************
! USE module_data_gocart_chem

  IMPLICIT NONE

  INTEGER, INTENT(IN) :: nmx, ndt1,imx,jmx,lmx
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(IN) :: airmas
!  REAL(kind_chem), INTENT(IN)    :: drydf(imx,jmx,nmx)
  REAL(kind_chem), INTENT(INOUT) :: tc(imx,jmx,lmx,nmx)
  REAL(kind_chem), INTENT(INOUT) :: tdry(imx,jmx,nmx)

!  REAL(kind_chem), DIMENSION(imx,jmx), INTENT(INOUT) :: depso4
  REAL(kind_chem), INTENT(IN) :: pso4_so2(imx,jmx,lmx)
  real(kind_chem), DIMENSION (imx,jmx),INTENT(IN) :: cossza

  INTEGER :: i, j, l
  REAL(kind_chem) :: so40, rk, rkt, so4 

  ! executable statements

  DO l = 1,lmx
     DO j = 1,jmx
        DO i = 1,imx

           so40 = tc(i,j,l,NSO4)

           ! RK: SO4 drydep frequency, s-1 
!           IF (l == 1) THEN
!              rk  = drydf(i,j,NSO4)
!              rkt = rk * REAL(ndt1)
!
!              so4 = so40 * EXP(-rkt) + pso4_so2(i,j,l)/rkt * (1.0 - EXP(-rkt))
!           ELSE
              so4 = so40 + pso4_so2(i,j,l)
!           END IF

           so4    = MAX(so4, 1.0D-16)
           tc(i,j,l,NSO4) = so4

           !  -------------------------------------------------------------- 
           !  DIAGNOSTICS:      SO4 dry deposition  (kgS/timestep)      
           !  -------------------------------------------------------------- 
!           IF (l == 1) &
!                depso4(i,j) = depso4(i,j) + (so40 - so4 + pso4_so2(i,j,l)) &
!                * airmas(i,j,l) / airmw * smw
           
        END DO
     END DO
  END DO

 ! tdry(:,:,NSO4) = depso4(:,:)*tcmw(NSO4)/smw ! kg of SO4

END SUBROUTINE chem_so4

!=============================================================================

SUBROUTINE chem_msa( imx,jmx,lmx,&
     nmx, ndt1, airmas, tc, tdry, cossza,&
     pmsa_dms)
!     depmsa, pmsa_dms)

! ****************************************************************************
! *                                                                          *
! *  This is MSA chemistry subroutine.                                       *
! *                                                                          *
! *  The Only production is from DMS oxidation (save in CHEM_DMS), and the   *
! *  only loss is dry depsition here.  Wet deposition will be treated in     *
! *  WETDEP subroutine.                                                      *
! *                                                                          *
! *  MSA = MSA_0 * exp(-dt) + PMSA_DMS/kt * (1.-exp(-kt))                    *
! *    where k = dry deposition.                                             *
! *                                                                          *
! ****************************************************************************
! USE module_data_gocart_chem

  IMPLICIT NONE

  INTEGER, INTENT(IN) :: nmx, ndt1,imx,jmx,lmx
  REAL(kind_chem), DIMENSION(imx,jmx,lmx), INTENT(IN) :: airmas
  REAL(kind_chem), DIMENSION(imx,jmx), INTENT(IN) :: cossza
!  REAL, INTENT(IN)    :: drydf(imx,jmx,nmx)
  REAL(kind_chem), INTENT(INOUT) :: tc(imx,jmx,lmx,nmx)
  REAL(kind_chem), INTENT(INOUT) :: tdry(imx,jmx,nmx)
!  REAL, DIMENSION(imx,jmx), INTENT(INOUT) :: depmsa
  REAL(kind_chem), INTENT(IN) :: pmsa_dms(imx,jmx,lmx)

  REAL(kind_chem) :: msa0, msa, rk, rkt
  INTEGER :: i, j, l
  
  ! executable statements
  
  DO l = 1,lmx
     DO j = 1,jmx
        DO i = 1,imx

           msa0 = tc(i,j,l,NMSA)

           ! RK: MSA drydep frequency, s-1 
!           IF (l == 1) THEN
!              rk  = drydf(i,j,NMSA)
!              rkt = rk * REAL(ndt1)
!
!              msa = msa0 * EXP(-rkt) &
!                   + pmsa_dms(i,j,l)/rkt * (1.0 - EXP(-rkt))
!
!           ELSE
              msa = msa0 + pmsa_dms(i,j,l)
!           END IF

           msa    = MAX(msa, 1.0D-16)
           tc(i,j,l,NMSA) = msa
           
           !  -------------------------------------------------------------- 
           !  DIAGNOSTICS:      MSA dry deposition  (kgS/timestep)     
           !  -------------------------------------------------------------- 
!           IF (l == 1) &
!                depmsa(i,j) = depmsa(i,j) + (msa0 - msa + pmsa_dms(i,j,l)) &
!                * airmas(i,j,l) / airmw * smw

        END DO
     END DO
  END DO

!  tdry(:,:,NMSA) = depmsa(:,:)*tcmw(NMSA)/smw ! kg of MSA

END SUBROUTINE chem_msa
SUBROUTINE szangle(imx, jmx, doy, xhour, sza, cossza,xlon,rlat)

!
! ****************************************************************************
! **                                                                        **
! **  This subroutine computes solar zenith angle (SZA):                    **
! **                                                                        **
! **      cos(SZA) = sin(LAT)*sin(DEC) + cos(LAT)*cos(DEC)*cos(AHR)         **
! **                                                                        **
! **  where LAT is the latitude angle, DEC is the solar declination angle,  **
! **  and AHR is the hour angle, all in radius.                             **
! **                                                                        **
! **  DOY = day-of-year, XHOUR = UT time (hrs).                             **
! **  XLON = longitude in degree, RLAT = latitude in radian.                **
! ****************************************************************************
!

  IMPLICIT NONE

  INTEGER, INTENT(IN)    :: imx, jmx
  INTEGER, INTENT(IN)    :: doy
  REAL(kind_chem),    INTENT(IN)    :: xhour
  REAL(kind_chem),    INTENT(OUT)   :: sza(imx,jmx), cossza(imx,jmx)

  REAL(kind_chem)    :: a0, a1, a2, a3, b1, b2, b3, r, dec, timloc, ahr,xlon,rlat
  real(kind_chem), parameter :: pi=3.14
  INTEGER :: i, j

  ! executable statements
  sza    = 0.
  cossza = 0.

  ! ***************************************************************************
  ! *  Solar declination angle:                                               *
  ! ***************************************************************************
  a0 = 0.006918
  a1 = 0.399912
  a2 = 0.006758
  a3 = 0.002697
  b1 = 0.070257
  b2 = 0.000907
  b3 = 0.000148
  r  = 2.0* pi * REAL(doy-1)/365.0
  !
  dec = a0 - a1*COS(  r)   + b1*SIN(  r)   &
           - a2*COS(2.0*r) + b2*SIN(2.0*r) &
           - a3*COS(3.0*r) + b3*SIN(3.0*r)
  !
  DO i = 1,imx
     ! ************************************************************************
     ! *  Hour angle (AHR) is a function of longitude.  AHR is zero at        *
     ! *  solar noon, and increases by 15 deg for every hour before or        *
     ! *  after solar noon.                                                   *
     ! ************************************************************************
     ! -- Local time in hours
     timloc  = xhour + xlon/15.0
     !      IF (timloc < 0.0) timloc = 24.0 + timloc
     IF (timloc > 24.0) timloc = timloc - 24.0
     !
     ! -- Hour angle
     ahr = ABS(timloc - 12.0) * 15.0 * pi/180.0
     !
     DO j = 1,jmx
        ! -- Solar zenith angle      
        cossza(i,j) = SIN(rlat) * SIN(dec) + &
                      COS(rlat) * COS(dec) * COS(ahr)
        sza(i,j)    = ACOS(cossza(i,j)) * 180.0/pi
        IF (cossza(i,j) < 0.0)   cossza(i,j) = 0.0
        !
     END do
  END DO
     
END subroutine szangle

end module gocart_chem_mod
