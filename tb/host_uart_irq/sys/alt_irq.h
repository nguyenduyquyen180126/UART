typedef unsigned alt_irq_context;
alt_irq_context alt_irq_disable_all(void);
void alt_irq_enable_all(alt_irq_context saved);
int alt_ic_isr_register(unsigned controller, unsigned irq, void (*handler)(void *), void *context, void *flags);
