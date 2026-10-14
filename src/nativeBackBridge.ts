import {isNativeIOS} from './nativeReminders';
import {attachBrowserEdgeBack,IOS_BACK_EVENT} from './iosGesture';

/**
 * Leave an active input/keyboard first. Then reuse the app's existing
 * back button, which persists a meaningful draft before navigation.
 * On a root tab, return to Inicio; never use WKWebView history.back().
 */
export function performNativeBack(doc:Document):'keyboard'|'page'|'home'|'noop'{
  const focused=doc.activeElement;
  if(focused instanceof HTMLElement && focused.matches('input,textarea,select,[contenteditable="true"]')){
    focused.blur();
    return 'keyboard';
  }
  // Kardex owns nested navigation. A swipe on Inventario, Movimientos,
  // Entregas or Reportes must first return to its four-tile dashboard.
  const nested=doc.querySelector<HTMLButtonElement>('.kardexSectionHeader > button');
  if(nested && !nested.disabled){nested.click();return 'page'}
  const back=doc.querySelector<HTMLButtonElement>('.pageHead > button');
  if(back && !back.disabled){back.click();return 'page'}
  const home=doc.querySelector<HTMLButtonElement>('nav > button:first-child');
  if(home && !home.classList.contains('active') && !home.disabled){home.click();return 'home'}
  return 'noop';
}

// Bind once outside of React so no state is lost during UI updates.
window.addEventListener(IOS_BACK_EVENT,()=>performNativeBack(document));
if(!isNativeIOS())attachBrowserEdgeBack(()=>performNativeBack(document));
