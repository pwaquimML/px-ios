//
//  InitFlow.swift
//  MercadoPagoSDK
//
//  Created by Juan sebastian Sanzone on 26/6/18.
//  Copyright © 2018 MercadoPago. All rights reserved.
//

import Foundation

final class InitFlow: PXFlow {
    var pxNavigationHandler: PXNavigationHandler
    let model: InitFlowModel

    private var status: PXFlowStatus = .ready
    private let finishInitCallback: ((PXCheckoutPreference, PXPaymentMethodSearch) -> Void)
    private let errorInitCallback: ((InitFlowError) -> Void)

    init(flowProperties: InitFlowProperties, finishCallback: @escaping ((PXCheckoutPreference, PXPaymentMethodSearch) -> Void), errorCallback: @escaping ((InitFlowError) -> Void)) {
        pxNavigationHandler = PXNavigationHandler.getDefault()
        finishInitCallback = finishCallback
        errorInitCallback = errorCallback
        model = InitFlowModel(flowProperties: flowProperties)
        PXTrackingStore.sharedInstance.cleanChoType()
    }

    func updateModel(paymentPlugin: PXSplitPaymentProcessor?, paymentMethodPlugins: [PXPaymentMethodPlugin]?, chargeRules: [PXPaymentTypeChargeRule]?) {
        var pmPlugins: [PXPaymentMethodPlugin] = [PXPaymentMethodPlugin]()
        if let targetPlugins = paymentMethodPlugins {
            pmPlugins = targetPlugins
        }
        model.update(paymentPlugin: paymentPlugin, paymentMethodPlugins: pmPlugins, chargeRules: chargeRules)
    }

    deinit {
        #if DEBUG
            print("DEINIT FLOW - \(self)")
        #endif
    }

    func start() {
        if status != .running {
            status = .running
            executeNextStep()
        }
    }

    func executeNextStep() {
        let nextStep = model.nextStep()
        switch nextStep {
        case .SERVICE_GET_PREFERENCE:
            getCheckoutPreference()
        case .ACTION_VALIDATE_PREFERENCE:
            validatePreference()
        case .SERVICE_GET_PAYMENT_METHODS:
            getPaymentMethodSearch()
        case .SERVICE_PAYMENT_METHOD_PLUGIN_INIT:
            initPaymentMethodPlugins()
        case .FINISH:
            finishFlow()
        case .ERROR:
            cancelFlow()
        }
    }

    func finishFlow() {
        status = .finished
        if let paymentMethodsSearch = model.getPaymentMethodSearch() {
            setCheckoutTypeForTracking()
            finishInitCallback(model.properties.checkoutPreference, paymentMethodsSearch)
        } else {
            cancelFlow()
        }
    }

    func cancelFlow() {
        status = .finished
        errorInitCallback(model.getError())
        model.resetError()
    }

    func exitCheckout() {}
}

// MARK: - Getters
extension InitFlow {
    func setFlowRetry(step: InitFlowModel.Steps) {
        status = .ready
        model.setPendingRetry(forStep: step)
    }

    func disposePendingRetry() {
        model.removePendingRetry()
    }

    func getStatus() -> PXFlowStatus {
        return status
    }

    func restart() {
        if status != .running {
            status = .ready
        }
    }
}

// MARK: - Privates
extension InitFlow {
    private func setCheckoutTypeForTracking() {
        if let paymentMethodsSearch = model.getPaymentMethodSearch() {
            PXTrackingStore.sharedInstance.setChoType(paymentMethodsSearch.expressCho != nil ? .one_tap : .traditional)
        }
    }
}
