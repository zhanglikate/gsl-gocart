!>\file gsd_chem_seas_wrapper.F90
!! This file is GSDChem sea salt wrapper with CCPP coupling to FV3
!! Haiqin.Li@noaa.gov 05/2020
!! Kate.Zhang@noaa.gov 02/2023

 module gsd_chem_seas_wrapper

   use physcons,        only : g => con_g, pi => con_pi
   use machine ,        only : kind_phys
   use gsd_chem_config
   use seas_mod,        only : gocart_seasalt_driver

   implicit none

   private

   public :: gsd_chem_seas_wrapper_init, gsd_chem_seas_wrapper_run, gsd_chem_seas_wrapper_finalize

contains

!> \brief Brief description of the subroutine
!!
      subroutine gsd_chem_seas_wrapper_init
      end subroutine gsd_chem_seas_wrapper_init

!> \brief Brief description of the subroutine
!!
!! \section arg_table_gsd_chem_seas_wrapper_finalize Argument Table
!!
      subroutine gsd_chem_seas_wrapper_finalize()
      end subroutine gsd_chem_seas_wrapper_finalize

!> \defgroup gsd_chem_seas_group GSD Chem seas wrapper Module
!! This is the gsd chemistry
!>\defgroup gsd_chem_seas_wrapper GSD Chem seas wrapper Module  
!> \ingroup gsd_chem_seas_group
!! This is the GSD Chem seas wrapper Module
!! \section arg_table_gsd_chem_seas_wrapper_run Argument Table
!! \htmlinclude gsd_chem_seas_wrapper_run.html
!!
!>\section gsd_chem_seas_wrapper GSD Chemistry Scheme General Algorithm
!> @{
    subroutine gsd_chem_seas_wrapper_run(im, kte, kme, ktau, dt, garea,          &
                   land, oceanfrac, fice, u10m, v10m, ustar, rlat, rlon, tskin,  &
                   pr3d, ph3d,prl3d, tk3d, us3d, vs3d, spechum,                  &
                   nseasalt,ntrac,ntss1,ntss2,ntss3,ntss4,ntss5,                 &
                   gq0,qgrs,ssem,seas_opt_in, sstemisFlag,seas_emis_scale,       & 
                   pert_scale_seas,       &
                   emis_amp_seas, do_sppt_emis, sppt_wts, errmsg, errflg)

    implicit none

    integer,        intent(in) :: im,kte,kme,ktau
    integer,        intent(in) :: nseasalt,ntrac,ntss1,ntss2,ntss3,ntss4,ntss5
    real(kind_phys),intent(in) :: dt

    logical,        intent(in) :: do_sppt_emis
    real(kind=kind_phys), intent(in)    :: emis_amp_seas, pert_scale_seas
    real(kind_phys), dimension(5), intent(in) :: seas_emis_scale
    real(kind_phys), optional, intent(in) :: sppt_wts(:,:)


    integer, parameter :: ids=1,jds=1,jde=1, kds=1
    integer, parameter :: ims=1,jms=1,jme=1, kms=1
    integer, parameter :: its=1,jts=1,jte=1, kts=1

    integer, dimension(im), intent(in) :: land
    real(kind_phys), dimension(im), intent(in) :: u10m, v10m, ustar,oceanfrac, fice,   &
                garea, rlat,rlon, tskin
    real(kind_phys), dimension(im,kme), intent(in) :: ph3d, pr3d
    real(kind_phys), dimension(im,kte), intent(in) :: prl3d, tk3d, us3d, vs3d, spechum
    real(kind_phys), dimension(im,kte,ntrac), intent(inout) :: gq0,qgrs
    real(kind_phys), dimension(im, nseasalt), intent(inout) :: ssem
    integer,        intent(in) :: seas_opt_in, sstemisFlag
    character(len=*), intent(out) :: errmsg
    integer,          intent(out) :: errflg

    real(kind_phys), dimension(1:im, 1:kme,jms:jme) :: rri, t_phy, u_phy, v_phy,       &
                     dz8w, p8w, rho_phy

    real(kind_phys), dimension(ims:im, jms:jme) :: u10, v10, ust, tsk,                 &
                     xland, frocean,fraci,xlat, xlong, dxy

!>- sea salt & chemistry variables
    real(kind_phys), dimension(ims:im, kms:kme, jms:jme, 1:num_chem )  :: chem
    real(kind_phys), dimension(ims:im, 1, jms:jme, 1:num_emis_seas  ) :: emis_seas
    real(kind_phys), dimension(ims:im, jms:jme) :: seashelp

    integer :: ide, ime, ite, kde
    real(kind_phys), dimension(1:num_chem) :: ppm2ugkg
    real(kind_phys) :: random_factor(ims:im,jms:jme)

!>-- local variables
    integer :: i, j, jp, k, kp, n
  

    errmsg = ''
    errflg = 0


    ! -- set domain
    ide=im 
    ime=im
    ite=im
    kde=kte

    ! -- volume to mass fraction conversion table (ppm -> ug/kg)
    ppm2ugkg         = 1._kind_phys
   !ppm2ugkg(p_so2 ) = 1.e+03_kind_phys * mw_so2_aer / mwdry
    ppm2ugkg(p_sulf) = 1.e+03_kind_phys * mw_so4_aer / mwdry

    if(do_sppt_emis) then
      random_factor(:,jms) = pert_scale_seas*max(min(1+(sppt_wts(:,kme/2)-1)*emis_amp_seas,2.0),0.0)
    else
      random_factor = 1.0
    endif

!>- get ready for chemistry run
    call gsd_chem_prep_seas(                                            &
        u10m,v10m,ustar,land,oceanfrac, fice, garea,rlat,rlon,tskin,    &
        pr3d,ph3d,tk3d,prl3d,us3d,vs3d,spechum,                         &
        u10,v10,ust,tsk,xland,frocean,fraci,xlat,xlong,dxy,             &
        rri,t_phy,u_phy,v_phy,rho_phy,dz8w,p8w,                         &
        ntss1,ntss2,ntss3,ntss4,ntss5,ntrac,gq0,                        &
        num_chem, ppm2ugkg,chem,                                        &
        ids,ide, jds,jde, kds,kde,                                      &
        ims,ime, jms,jme, kms,kme,                                      &
        its,ite, jts,jte, kts,kte)


    ! -- compute sea salt
    if (seas_opt_in >= SEAS_OPT_DEFAULT) then
    call gocart_seasalt_driver(ktau,dt,rri,t_phy,                       &
        u_phy,v_phy,chem,rho_phy,dz8w,u10,v10,ust,p8w,tsk,              &
        xland,frocean,fraci,xlat,xlong,dxy,g,emis_seas,                 &
        seashelp,num_emis_seas,num_chem,seas_opt_in,                    &
        sstemisFlag,seas_emis_scale, random_factor,                     &
        ids,ide, jds,jde, kds,kde,                                      &
        ims,ime, jms,jme, kms,kme,                                      &
        its,ite, jts,jte, kts,kte)
    endif 

    ! -- put chem stuff back into tracer array
    do k=kts,kte
     do i=its,ite
       gq0(i,k,ntss1  )=ppm2ugkg(p_seas_1) * max(epsilc,chem(i,k,1,p_seas_1))
       gq0(i,k,ntss2  )=ppm2ugkg(p_seas_2) * max(epsilc,chem(i,k,1,p_seas_2))
       gq0(i,k,ntss3  )=ppm2ugkg(p_seas_3) * max(epsilc,chem(i,k,1,p_seas_3))
       gq0(i,k,ntss4  )=ppm2ugkg(p_seas_4) * max(epsilc,chem(i,k,1,p_seas_4))
       gq0(i,k,ntss5  )=ppm2ugkg(p_seas_5) * max(epsilc,chem(i,k,1,p_seas_5))
     enddo
    enddo

    do k=kts,kte
     do i=its,ite
       qgrs(i,k,ntss1 )=gq0(i,k,ntss1 )
       qgrs(i,k,ntss2 )=gq0(i,k,ntss2 )
       qgrs(i,k,ntss3 )=gq0(i,k,ntss3 )
       qgrs(i,k,ntss4 )=gq0(i,k,ntss4 )
       qgrs(i,k,ntss5 )=gq0(i,k,ntss5 )
     enddo
    enddo

    do i=1,im
     do n=1,nseasalt
      ssem(i,n)=emis_seas(i,1,1,n)
     enddo
   enddo

!
   end subroutine gsd_chem_seas_wrapper_run
!> @}

   subroutine gsd_chem_prep_seas(                                      &
        u10m,v10m,ustar,land,oceanfrac, fice,garea,rlat,rlon,ts2d,     &
        pr3d,ph3d,tk3d,prl3d,us3d,vs3d,spechum,                        &
        u10,v10,ust,tsk,xland,frocean,fraci,xlat,xlong,dxy,            &
        rri,t_phy,u_phy,v_phy,rho_phy,dz8w,p8w,                        &
        ntss1,ntss2,ntss3,ntss4,ntss5,ntrac,gq0,                       &
        num_chem, ppm2ugkg,chem,                                       &
        ids,ide, jds,jde, kds,kde,                                     &
        ims,ime, jms,jme, kms,kme,                                     &
        its,ite, jts,jte, kts,kte)

    !Chem input configuration

    !FV3 input variables
    integer, dimension(ims:ime), intent(in) :: land
    integer, intent(in) :: ntrac,ntss1,ntss2,ntss3,ntss4,ntss5
    real(kind=kind_phys), dimension(ims:ime), intent(in) ::oceanfrac,fice, & 
         u10m, v10m, ustar, garea, rlat, rlon, ts2d
    real(kind=kind_phys), dimension(ims:ime, kms:kme), intent(in) :: pr3d,ph3d
    real(kind=kind_phys), dimension(ims:ime, kts:kte), intent(in) ::       &
         tk3d,prl3d,us3d,vs3d,spechum
    real(kind=kind_phys), dimension(ims:ime, kts:kte,ntrac), intent(in) :: gq0


    !GSD Chem variables
    integer,intent(in) ::  num_chem
    integer,intent(in) ::  ids,ide, jds,jde, kds,kde,                       &
                           ims,ime, jms,jme, kms,kme,                       &
                           its,ite, jts,jte, kts,kte

    real(kind_phys), dimension(num_chem), intent(in) :: ppm2ugkg

    real(kind_phys), dimension(ims:ime, kms:kme, jms:jme), intent(out) ::              & 
         rri, t_phy, u_phy, v_phy, rho_phy, dz8w, p8w
    real(kind_phys), dimension(ims:ime, jms:jme),          intent(out) ::              &
         u10, v10, ust, tsk, xland, frocean,fraci, xlat, xlong, dxy
    real(kind_phys), dimension(ims:ime, kms:kme, jms:jme, num_chem),  intent(out) :: chem


    ! -- local variables
    real(kind_phys), dimension(ims:ime, kms:kme, jms:jme) :: z_at_w, p_phy
    integer i,ip,j,jp,k,kp,kk,kkp,l,ll,n

    ! -- initialize output arrays
    rri            = 0._kind_phys
    t_phy          = 0._kind_phys
    u_phy          = 0._kind_phys
    v_phy          = 0._kind_phys
    rho_phy        = 0._kind_phys
    dz8w           = 0._kind_phys
    p8w            = 0._kind_phys
    u10            = 0._kind_phys
    v10            = 0._kind_phys
    ust            = 0._kind_phys
    tsk            = 0._kind_phys
    xland          = 0._kind_phys
    frocean        = 0._kind_phys
    fraci          = 0._kind_phys
    xlat           = 0._kind_phys
    xlong          = 0._kind_phys
    dxy            = 0._kind_phys
    chem           = 0._kind_phys


    do i=its,ite
     u10  (i,1)=u10m (i)
     v10  (i,1)=v10m (i)
     tsk  (i,1)=ts2d (i)
     ust  (i,1)=ustar(i)
     dxy  (i,1)=garea(i)
     xland(i,1)=real(land(i))
     frocean(i,1)=oceanfrac(i)
     fraci(i,1)=fice(i)
     xlat (i,1)=rlat(i)*180./pi
     xlong(i,1)=rlon(i)*180./pi
    enddo
   
    do j=jts,jte
      jp = j - jts + 1
      do i=its,ite
         ip = i - its + 1
         z_at_w(i,kts,j)=max(0.,ph3d(ip,1)/g)
      enddo
    enddo

    do j=jts,jte
      jp = j - jts + 1
      do k=kts,kte
        kp = k - kts + 1
        do i=its,ite
          ip = i - its + 1
          dz8w(i,k,j)=abs(ph3d(ip,kp+1)-ph3d(ip,kp))/g
          z_at_w(i,k+1,j)=z_at_w(i,k,j)+dz8w(i,k,j)
        enddo
      enddo
    enddo

    do j=jts,jte
      jp = j - jts + 1
      do k=kts,kte+1
        kp = k - kts + 1
        do i=its,ite
          ip = i - its + 1
          p8w(i,k,j)=pr3d(ip,kp)
        enddo
      enddo
    enddo

    do j=jts,jte
      jp = j - jts + 1
      do k=kts,kte+1
        kk=min(k,kte)
        kkp = kk - kts + 1
        do i=its,ite
          ip = i - its + 1
          dz8w(i,k,j)=z_at_w(i,kk+1,j)-z_at_w(i,kk,j)
          t_phy(i,k,j)=tk3d(ip,kkp)
          p_phy(i,k,j)=prl3d(ip,kkp)
          u_phy(i,k,j)=us3d(ip,kkp)
          v_phy(i,k,j)=vs3d(ip,kkp)
          rho_phy(i,k,j)=p_phy(i,k,j)/(287.04*t_phy(i,k,j)*(1.+.608*spechum(ip,kkp)))
          rri(i,k,j)=1./rho_phy(i,k,j)
          !--
        enddo
      enddo
    enddo

 
    do k=kms,kte
     do i=ims,ime
       chem(i,k,jts,p_seas_1)=max(epsilc,gq0(i,k,ntss1  )/ppm2ugkg(p_seas_1))
       chem(i,k,jts,p_seas_2)=max(epsilc,gq0(i,k,ntss2  )/ppm2ugkg(p_seas_2))
       chem(i,k,jts,p_seas_3)=max(epsilc,gq0(i,k,ntss3  )/ppm2ugkg(p_seas_3))
       chem(i,k,jts,p_seas_4)=max(epsilc,gq0(i,k,ntss4  )/ppm2ugkg(p_seas_4))
       chem(i,k,jts,p_seas_5)=max(epsilc,gq0(i,k,ntss5  )/ppm2ugkg(p_seas_5))
     enddo
    enddo


  end subroutine gsd_chem_prep_seas
!> @}
  end module gsd_chem_seas_wrapper
