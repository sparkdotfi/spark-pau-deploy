// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IEnumerableIntegrations as IEI } from "../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { Beacon }     from "../lib/diamond-pau/src/Beacon.sol";
import { PAUFactory } from "../lib/diamond-pau/src/PAUFactory.sol";

import { CCTPFacet } from "../lib/diamond-pau/src/facets/cctp/CCTPFacet.sol";

import { IMainnetControllerFull as IControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { AdministeredAgentFactory } from "../lib/pau-administered-agent/src/AdministeredAgentFactory.sol";

import { CCTPFacetWiring } from "./CCTPFacetWiring.sol";

interface IAccessControlLike {

    function getConfig(bytes32 integrationId) external view returns (IEI.Config memory config);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function revokeRole(bytes32 role, address account) external;

}

interface IAdministeredAgentLike {

    function addActor(address account) external;

    function addAdmin(address account) external;

    function addGrantor(address account) external;

    function addRevoker(address account) external;

    function getIsAdmin(address account) external view returns (bool);

    function removeAdmin(address account) external;

}

interface IALMProxyLike {

    function CONTROLLER() external view returns (bytes32);

}

interface IRateLimitsLike is IAccessControlLike {

    function CONTROLLER() external view returns (bytes32);

}

/**
 * @title  ParallelPAULib
 * @notice The two production steps for a parallel Diamond PAU controller on a chain with no
 *         Diamond PAU infrastructure, next to an EXISTING ALMProxy. Used by the deploy and
 *         configure scripts and by the fork test that runs the same code path end to end.
 *
 *         Neither step touches the existing ALMProxy. Granting CONTROLLER to the new controller
 *         and setting rate limits are governance spell actions.
 */
library ParallelPAULib {

    bytes32 internal constant ALLOCATOR_ROLE     = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    struct DeployParams {
        address deployer;            // Sender of every transaction, admin until configure runs.
        address almProxy;            // Existing custody contract the controller is deployed against.
        address cctpTokenMessenger;  // Circle TokenMessengerV2 on this chain.
        address usdc;                // Native USDC on this chain.
    }

    struct Deployment {
        address beacon;
        address cctpFacet;
        address pauFactory;
        address agentFactory;
        address accessControls;
        address rateLimits;
        address controller;
        address administeredAgent;
    }

    struct CCTPDomain {
        uint32  domainId;
        address mintRecipient;
        uint32  minFeeCapRate;
        uint32  maxFeeCapRate;
    }

    struct ConfigureParams {
        address      controller;
        address      administeredAgent;
        address      admin;      // Receives every admin role.
        address      deployer;   // Loses every admin role.
        address      freezer;    // AdministeredAgent revoker.
        address      grantor;    // AdministeredAgent grantor, optional.
        address[]    relayers;   // AdministeredAgent actors.
        CCTPDomain[] cctpDomains;
    }

    /**********************************************************************************************/
    /*** Deploy                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Deploys Beacon, CCTPFacet (wired), PAUFactory, AdministeredAgentFactory, then
     *         AccessControls, RateLimits, Controller (against `almProxy`) and one
     *         AdministeredAgent. `deployer` is admin of everything.
     */
    function deploy(DeployParams memory p) internal returns (Deployment memory d) {
        validateDeployParams(p);

        // Step 1: Beacon, owned by the deployer until configure hands it over.
        Beacon beacon = new Beacon(p.deployer);

        // Step 2: CCTP facet, wired on the Beacon with the canonical selector set.
        d.cctpFacet = address(new CCTPFacet({
            cctp_ : p.cctpTokenMessenger,
            usdc_ : p.usdc
        }));

        beacon.setIntegration(CCTPFacetWiring.INTEGRATION_ID, CCTPFacetWiring.config(d.cctpFacet));

        // Step 3: Factories.
        PAUFactory               pauFactory   = new PAUFactory(address(beacon));
        AdministeredAgentFactory agentFactory = new AdministeredAgentFactory();

        // Step 4: Controller stack against the existing ALMProxy, plus one AdministeredAgent.
        d.beacon            = address(beacon);
        d.pauFactory        = address(pauFactory);
        d.agentFactory      = address(agentFactory);
        d.accessControls    = pauFactory.deployAccessControls(p.deployer);
        d.rateLimits        = pauFactory.deployRateLimits(p.deployer);
        d.controller        = pauFactory.deployController(d.accessControls, p.almProxy, d.rateLimits);
        d.administeredAgent = agentFactory.deploy(p.deployer);
    }

    function validateDeployParams(DeployParams memory p) internal view {
        require(p.deployer != address(0),             "ParallelPAULib/zero-deployer");
        require(p.almProxy.code.length > 0,           "ParallelPAULib/alm-proxy-no-code");
        require(p.cctpTokenMessenger.code.length > 0, "ParallelPAULib/cctp-no-code");
        require(p.usdc.code.length > 0,               "ParallelPAULib/usdc-no-code");

        // The existing custody contract must expose the CONTROLLER role the spell will grant.
        require(
            IALMProxyLike(p.almProxy).CONTROLLER() == keccak256("CONTROLLER"),
            "ParallelPAULib/unexpected-alm-proxy"
        );
    }

    /**********************************************************************************************/
    /*** Configure                                                                              ***/
    /**********************************************************************************************/

    /**
     * @notice Configures roles and the CCTP integration, then hands every admin role from
     *         `deployer` to `admin`. Must be called by `deployer`.
     */
    function configure(ConfigureParams memory p) internal {
        IControllerFull        controller = IControllerFull(p.controller);
        IAdministeredAgentLike agent      = IAdministeredAgentLike(p.administeredAgent);

        IAccessControlLike beacon         = IAccessControlLike(controller.beacon());
        IAccessControlLike accessControls = IAccessControlLike(controller.accessControls());
        IRateLimitsLike    rateLimits     = IRateLimitsLike(controller.rateLimits());

        validateConfigureParams(p);

        // Step 1: AdministeredAgent actors, grantor and revoker.
        for (uint256 i = 0; i < p.relayers.length; ++i) {
            agent.addActor(p.relayers[i]);
        }

        if (p.grantor != address(0)) agent.addGrantor(p.grantor);

        agent.addRevoker(p.freezer);

        // Step 2: The AdministeredAgent is the only allocator on the new controller.
        accessControls.grantRole(ALLOCATOR_ROLE, p.administeredAgent);

        // Step 3: The Controller meters against its own dedicated RateLimits instance.
        rateLimits.grantRole(rateLimits.CONTROLLER(), p.controller);

        // Step 4: Sync the CCTP facet from the Beacon. This is the only integration.
        bytes32[] memory integrationIds = new bytes32[](1);

        integrationIds[0] = CCTPFacetWiring.INTEGRATION_ID;

        controller.updateIntegrations(integrationIds);

        // Step 5: CCTP domain parameters. Not rate limits, so not a spell action.
        for (uint256 i = 0; i < p.cctpDomains.length; ++i) {
            CCTPDomain memory domain = p.cctpDomains[i];

            controller.cctp_setDomainParameters(
                domain.domainId,
                bytes32(uint256(uint160(domain.mintRecipient))),
                domain.minFeeCapRate,
                domain.maxFeeCapRate
            );
        }

        // Step 6: Hand every admin role to `admin`, then drop the deployer.
        beacon.grantRole(DEFAULT_ADMIN_ROLE,         p.admin);
        accessControls.grantRole(DEFAULT_ADMIN_ROLE, p.admin);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE,     p.admin);

        agent.addAdmin(p.admin);

        beacon.revokeRole(DEFAULT_ADMIN_ROLE,         p.deployer);
        accessControls.revokeRole(DEFAULT_ADMIN_ROLE, p.deployer);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE,     p.deployer);

        agent.removeAdmin(p.deployer);
    }

    function validateConfigureParams(ConfigureParams memory p) internal view {
        IControllerFull controller = IControllerFull(p.controller);

        IAccessControlLike     beacon         = IAccessControlLike(controller.beacon());
        IAccessControlLike     accessControls = IAccessControlLike(controller.accessControls());
        IRateLimitsLike        rateLimits     = IRateLimitsLike(controller.rateLimits());
        IAdministeredAgentLike agent          = IAdministeredAgentLike(p.administeredAgent);

        require(p.admin    != address(0), "ParallelPAULib/zero-admin");
        require(p.deployer != address(0), "ParallelPAULib/zero-deployer");
        require(p.freezer  != address(0), "ParallelPAULib/zero-freezer");
        require(p.admin    != p.deployer, "ParallelPAULib/admin-is-deployer");

        require(p.relayers.length > 0,    "ParallelPAULib/no-relayers");
        require(p.cctpDomains.length > 0, "ParallelPAULib/no-cctp-domains");

        for (uint256 i = 0; i < p.relayers.length; ++i) {
            require(p.relayers[i] != address(0), "ParallelPAULib/zero-relayer");
        }

        for (uint256 i = 0; i < p.cctpDomains.length; ++i) {
            require(p.cctpDomains[i].mintRecipient != address(0), "ParallelPAULib/zero-mint-recipient");
        }

        // The deployer must still hold every admin role this step hands over.
        require(beacon.hasRole(DEFAULT_ADMIN_ROLE, p.deployer),         "ParallelPAULib/deployer-not-beacon-admin");
        require(accessControls.hasRole(DEFAULT_ADMIN_ROLE, p.deployer), "ParallelPAULib/deployer-not-ac-admin");
        require(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, p.deployer),     "ParallelPAULib/deployer-not-rl-admin");
        require(agent.getIsAdmin(p.deployer),                           "ParallelPAULib/deployer-not-agent-admin");

        // The Beacon must already carry the CCTP facet this step syncs.
        require(
            beacon.getConfig(CCTPFacetWiring.INTEGRATION_ID).facet != address(0),
            "ParallelPAULib/cctp-facet-not-on-beacon"
        );
    }

    /**
     * @notice End-state checks after `configure`. Reverts with a reason on any deviation, so a
     *         script run aborts in simulation before anything is broadcast.
     */
    function checkConfigured(ConfigureParams memory p) internal view {
        IControllerFull        controller = IControllerFull(p.controller);
        IAdministeredAgentLike agent      = IAdministeredAgentLike(p.administeredAgent);

        IAccessControlLike beacon         = IAccessControlLike(controller.beacon());
        IAccessControlLike accessControls = IAccessControlLike(controller.accessControls());
        IRateLimitsLike    rateLimits     = IRateLimitsLike(controller.rateLimits());

        require(beacon.hasRole(DEFAULT_ADMIN_ROLE, p.admin),         "ParallelPAULib/post/beacon-admin");
        require(accessControls.hasRole(DEFAULT_ADMIN_ROLE, p.admin), "ParallelPAULib/post/ac-admin");
        require(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, p.admin),     "ParallelPAULib/post/rl-admin");
        require(agent.getIsAdmin(p.admin),                           "ParallelPAULib/post/agent-admin");

        require(!beacon.hasRole(DEFAULT_ADMIN_ROLE, p.deployer),         "ParallelPAULib/post/beacon-deployer");
        require(!accessControls.hasRole(DEFAULT_ADMIN_ROLE, p.deployer), "ParallelPAULib/post/ac-deployer");
        require(!rateLimits.hasRole(DEFAULT_ADMIN_ROLE, p.deployer),     "ParallelPAULib/post/rl-deployer");
        require(!agent.getIsAdmin(p.deployer),                           "ParallelPAULib/post/agent-deployer");

        require(accessControls.hasRole(ALLOCATOR_ROLE, p.administeredAgent),      "ParallelPAULib/post/allocator");
        require(rateLimits.hasRole(rateLimits.CONTROLLER(), p.controller),        "ParallelPAULib/post/rl-controller");

        IEI.Config memory beaconConfig     = beacon.getConfig(CCTPFacetWiring.INTEGRATION_ID);
        IEI.Config memory controllerConfig = controller.getConfig(CCTPFacetWiring.INTEGRATION_ID);

        require(controllerConfig.facet == beaconConfig.facet,                "ParallelPAULib/post/facet");
        require(controllerConfig.wires.length == CCTPFacetWiring.WIRE_COUNT, "ParallelPAULib/post/wires");
        require(controller.integrations().length == 1,                       "ParallelPAULib/post/integrations");

        for (uint256 i = 0; i < p.cctpDomains.length; ++i) {
            ( bytes32 recipient, , ) = controller.cctp_getDomainParameters(p.cctpDomains[i].domainId);

            require(
                recipient == bytes32(uint256(uint160(p.cctpDomains[i].mintRecipient))),
                "ParallelPAULib/post/mint-recipient"
            );
        }
    }

}
